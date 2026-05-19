# Сервер «завис» или упал при `docker compose build`

Чаще всего это **не «тишина»**, а **нехватка RAM** (OOM killer убил Docker/SSH) или **диск забит** кешем сборок.

## Быстрая диагностика (после перезагрузки / когда снова зайдёшь по SSH)

```bash
free -h
df -h /
df -h /var/lib/docker
dmesg -T | tail -80 | grep -i -E 'oom|killed|out of memory' || true
docker system df
```

## Типовые решения

### 1. Мало RAM (1–2 GB VPS)

Добавь swap (например 2 GB) и пересобери:

```bash
fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

В `.env.server` при необходимости подними лимит памяти сборки Node (по умолчанию 768 MB в образе):

```bash
NODE_BUILD_MEMORY_MB=1536
```

### 2. Контекст сборки nginx таскал весь монорепозиторий

В репозитории добавлен корневой **`.dockerignore`**, чтобы в Docker не отправлялись `apps/`, `backend/` и т.д. при сборке nginx — обязательно `git pull` и сборка снова.

### 3. Диск забит слоями build

```bash
docker builder prune -af
docker image prune -af
```

(осторожно: удалит неиспользуемые образы; работающие контейнеры не тронет.)

### 4. Порт MinIO на хосте занят (`Bind for :::9000 failed`)

На машине уже что‑то слушает **9000** (часто старый MinIO или другой стек).

Либо освободи порт (`docker ps`, `ss -tlnp | grep 9000`), либо в **`.env.server`** задай другой проброс, например:

```bash
MINIO_HOST_PORT=9002
```

(`MINIO_HOST_PORT` — только публикация на хост; контейнер `api` по‑прежнему ходит в MinIO как `minio:9000` внутри сети compose.)

После правки: `docker compose --env-file .env.server up -d`.

### 4b. Занят порт консоли MinIO (`Bind ... :9001 failed`)

На хосте уже что‑то слушает **9001**. В **`.env.server`** задай другой проброс (внутри контейнера консоль всё равно **9001**):

```bash
MINIO_CONSOLE_HOST_PORT=9011
```

### 4c. Prisma `P1001 Can't reach database server at postgres:5432`

Часто это гонка при старте (особенно после рестарта Postgres). В образе API **`docker-entrypoint`** несколько раз повторяет `prisma migrate deploy`, пока БД не ответит.

После обновления репозитория пересобери API и поднись заново:

```bash
docker compose --env-file .env.server build api --no-cache
docker compose --env-file .env.server up -d
```

Если ошибка не уходит — проверь, что контейнер **`postgres` healthy**: `docker compose ps`, логи `docker compose logs postgres`.

### 5. Смотреть, на чём реально стопорится сборка API

```bash
cd /opt/klanymobail   # или твой каталог с compose
DOCKER_BUILDKIT=1 docker compose --env-file .env.server build api --progress=plain --no-cache 2>&1 | tee /tmp/build-api.log
```

Если обрыв на `npm ci` — сеть/registry; если на `npm run build` — CPU/RAM.

### Долго висит только строка `> klany-backend@0.0.1 build`

Nest по умолчанию собирает через **Webpack**. На слабом CPU это легко **3–15+ минут**, при этом в логе долго ничего нового — это норма, если **растёт время шага** в выводе BuildKit (`RUN npm run build ... Xm Ys`).

В репозитории подключён `backend/webpack.config.js` с **`ProgressPlugin`**: в логе сборки должны появляться строки `[nest/webpack] …% …` каждые ~10% — так видно, что процесс живой.

Если время шага **не растёт десятки минут**, CPU в `top` нулевой и лога нет — тогда уже смотреть OOM/диск (`dmesg`, `df`).

## Поднять только базы без сборки API (если образ уже был)

Если образ `api` уже собран раньше:

```bash
docker compose --env-file .env.server up -d postgres redis minio
```

Полный стек после фикса — как обычно: `./scripts/server/stack-up.sh` или `docker compose ... up -d --build`.
