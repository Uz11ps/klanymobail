import os
import sys
import subprocess
import tempfile
import time
import tarfile
from dataclasses import dataclass

import paramiko
from scp import SCPClient
from dotenv import load_dotenv


@dataclass(frozen=True)
class DeployConfig:
    server: str
    user: str
    password: str
    app_dir: str
    env_file: str
    compose_file: str
    keep_releases: int


def _required(name: str) -> str:
    v = (os.getenv(name) or "").strip()
    if not v:
        raise RuntimeError(f"Missing required env var: {name}")
    return v


def _read_int(name: str, default: int) -> int:
    raw = (os.getenv(name) or "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError as e:
        raise RuntimeError(f"Invalid int for {name}: {raw}") from e


def _run(cmd: list[str], *, cwd: str | None = None) -> str:
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if p.returncode != 0:
        msg = (p.stderr or p.stdout or "").strip()
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\n{msg}")
    return (p.stdout or "").strip()


def _git_repo_root() -> str:
    return _run(["git", "rev-parse", "--show-toplevel"])


def _git_commit_short(cwd: str) -> str:
    return _run(["git", "rev-parse", "--short", "HEAD"], cwd=cwd).strip()


def _git_is_dirty(cwd: str) -> bool:
    out = _run(["git", "status", "--porcelain"], cwd=cwd)
    return bool(out.strip())


def _git_archive_head(out_path: str, *, cwd: str) -> None:
    _run(["git", "archive", "--format=tar.gz", "-o", out_path, "HEAD"], cwd=cwd)


def _git_archive_worktree(out_path: str, *, cwd: str) -> None:
    """
    Create tar.gz from the current working tree (tracked + untracked files),
    respecting .gitignore. This allows deploying uncommitted changes when
    ALLOW_DIRTY=1 without forcing a commit.
    """
    tracked = _run(["git", "ls-files", "-z"], cwd=cwd)
    untracked = _run(["git", "ls-files", "--others", "--exclude-standard", "-z"], cwd=cwd)
    files = [p for p in (tracked + untracked).split("\0") if p]

    # admin_web is intentionally gitignored but must be deployed as nginx static assets.
    admin_web_dir = os.path.join(cwd, "infra", "nginx", "admin_web")
    if os.path.isdir(admin_web_dir):
        for root, _, filenames in os.walk(admin_web_dir):
            for name in filenames:
                abs_fp = os.path.join(root, name)
                rel_fp = os.path.relpath(abs_fp, cwd).replace("\\", "/")
                files.append(rel_fp)

    # keep stable order and remove duplicates
    files = sorted(set(files))

    with tarfile.open(out_path, "w:gz") as tf:
        for rel in files:
            abs_path = os.path.join(cwd, rel)
            if not os.path.exists(abs_path):
                continue
            # Force POSIX paths inside archive (Linux remote).
            arcname = rel.replace("\\", "/")
            tf.add(abs_path, arcname=arcname, recursive=False)


def create_ssh_client(server: str, user: str, password: str) -> paramiko.SSHClient:
    last_err: Exception | None = None
    for attempt in range(1, 6):
        try:
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            client.connect(
                server,
                username=user,
                password=password,
                timeout=30,
                banner_timeout=120,
                auth_timeout=60,
                look_for_keys=False,
                allow_agent=False,
            )
            return client
        except Exception as e:
            last_err = e
            # Small backoff: SSH banner exchange can be flaky right after reboot.
            time.sleep(min(2 * attempt, 10))
    raise RuntimeError(f"SSH connect failed after retries: {last_err}")


def _ssh_exec(ssh: paramiko.SSHClient, cmd: str) -> str:
    stdin, stdout, stderr = ssh.exec_command(cmd)
    _ = stdin
    out = (stdout.read() or b"").decode("utf-8", errors="ignore")
    err = (stderr.read() or b"").decode("utf-8", errors="ignore")
    if err.strip():
        # docker compose prints warnings to stderr; keep but don't fail unless exit status says so
        pass
    exit_code = stdout.channel.recv_exit_status()
    if exit_code != 0:
        msg = (err or out).strip()
        raise RuntimeError(f"Remote command failed ({exit_code}): {cmd}\n{msg}")
    return (out or "").strip()


def _ssh_exec_streaming(ssh: paramiko.SSHClient, cmd: str, *, timeout_sec: int) -> None:
    # Stream output to avoid "silent hang" during docker builds.
    stdin, stdout, stderr = ssh.exec_command(cmd, get_pty=True)
    _ = stdin
    ch = stdout.channel
    start = time.time()

    def _safe_write(stream, data: bytes) -> None:
        text = data.decode("utf-8", errors="ignore")
        try:
            stream.write(text)
        except UnicodeEncodeError:
            stream.write(text.encode(stream.encoding or "utf-8", errors="replace").decode(stream.encoding or "utf-8", errors="replace"))
        stream.flush()

    def _drain() -> None:
        while ch.recv_ready():
            _safe_write(sys.stdout, ch.recv(4096))
        while ch.recv_stderr_ready():
            _safe_write(sys.stderr, ch.recv_stderr(4096))

    while True:
        _drain()
        if ch.exit_status_ready():
            break
        if time.time() - start > timeout_sec:
            try:
                ch.close()
            except Exception:
                pass
            raise RuntimeError(f"Remote command timeout after {timeout_sec}s")
        time.sleep(0.25)

    _drain()
    exit_code = ch.recv_exit_status()
    if exit_code != 0:
        raise RuntimeError(f"Remote command failed ({exit_code})")


def deploy() -> None:
    load_dotenv(".env.deploy")
    load_dotenv()  # allow regular environment override

    cfg = DeployConfig(
        server=_required("VPS_IP"),
        user=(os.getenv("VPS_USER") or "root").strip() or "root",
        password=_required("VPS_PASSWORD"),
        app_dir=(os.getenv("APP_DIR") or "/opt/klany").strip() or "/opt/klany",
        env_file=(os.getenv("ENV_FILE") or ".env").strip() or ".env",
        compose_file=(os.getenv("COMPOSE_FILE") or "docker-compose.yml").strip() or "docker-compose.yml",
        keep_releases=_read_int("KEEP_RELEASES", 5),
    )

    repo_root = _git_repo_root()
    env_path = os.path.join(repo_root, cfg.env_file)
    compose_path = os.path.join(repo_root, cfg.compose_file)
    if not os.path.exists(env_path):
        raise RuntimeError(f"Env file not found: {env_path}")
    if not os.path.exists(compose_path):
        raise RuntimeError(f"Compose file not found: {compose_path}")

    if _git_is_dirty(repo_root) and (os.getenv("ALLOW_DIRTY") or "").strip().lower() not in ("1", "true", "yes"):
        raise RuntimeError("Worktree is dirty. Commit changes or set ALLOW_DIRTY=1 for deploy.")

    commit = _git_commit_short(repo_root)
    release = _run(["powershell", "-NoProfile", "-Command", "(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')"]).strip()
    release_name = f"{release}-{commit}"
    remote_tgz = f"/tmp/klany-{release_name}.tgz"
    remote_release_dir = f"{cfg.app_dir}/releases/{release_name}"
    remote_env = f"{cfg.app_dir}/shared/.env"

    print(f"[deploy] Connecting to {cfg.user}@{cfg.server} ...")
    ssh = create_ssh_client(cfg.server, cfg.user, cfg.password)
    try:
        _ssh_exec(ssh, f"mkdir -p '{cfg.app_dir}/releases' '{cfg.app_dir}/shared'")

        with tempfile.NamedTemporaryFile(prefix="klany-", suffix=".tgz", delete=False) as tmp:
            archive_path = tmp.name

        try:
            if _git_is_dirty(repo_root):
                print(f"[deploy] Packing git worktree (ALLOW_DIRTY=1) -> {archive_path}")
                _git_archive_worktree(archive_path, cwd=repo_root)
            else:
                print(f"[deploy] Packing git HEAD -> {archive_path}")
                _git_archive_head(archive_path, cwd=repo_root)

            print("[deploy] Uploading archive and env...")
            with SCPClient(ssh.get_transport()) as scp:
                scp.put(archive_path, remote_path=remote_tgz)
                scp.put(env_path, remote_path=remote_env)

            keep_from = max(int(cfg.keep_releases), 1) + 1
            remote_script = f"""
set -euo pipefail

APP_DIR='{cfg.app_dir}'
REL_DIR='{remote_release_dir}'
TGZ='{remote_tgz}'
ENV_FILE='{remote_env}'
COMPOSE_FILE='{cfg.compose_file}'
KEEP_FROM='{keep_from}'

mkdir -p "$APP_DIR/releases" "$APP_DIR/shared"
mkdir -p "$REL_DIR"

tar -xzf "$TGZ" -C "$REL_DIR"
rm -f "$TGZ"

ln -sfn "$REL_DIR" "$APP_DIR/current"
cd "$APP_DIR/current"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed"
  exit 1
fi

docker compose version >/dev/null 2>&1 || (echo "docker compose plugin is missing" && exit 1)

echo "[remote] building api + nginx images..."
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" build --progress=plain api nginx
echo "[remote] starting stack..."
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps

cd "$APP_DIR/releases"
ls -1dt */ 2>/dev/null | tail -n +"$KEEP_FROM" | xargs -r rm -rf --
""".strip()

            print(f"[deploy] Deploying release {release_name} ...")
            # Execute as one command: write temp script then run bash
            remote_script_escaped = remote_script.replace("'", "'\"'\"'")
            _ssh_exec_streaming(
                ssh,
                f"bash -lc '{remote_script_escaped}'",
                timeout_sec=30 * 60,  # docker build on VPS can be slow
            )

            print(f"[deploy] OK: {cfg.app_dir}/current -> {release_name}")
        finally:
            try:
                os.remove(archive_path)
            except OSError:
                pass
    finally:
        ssh.close()


if __name__ == "__main__":
    try:
        deploy()
    except Exception as e:
        print(f"[deploy] ERROR: {e}", file=sys.stderr)
        sys.exit(1)

