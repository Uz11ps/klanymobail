import {
  BadRequestException,
  Injectable,
  Logger,
  OnModuleInit,
} from "@nestjs/common";
import { Client } from "minio";

type BucketName = "quest-evidence" | "shop-products" | "member-avatars";

function toBool(v: string | undefined, def: boolean): boolean {
  if (v == null) return def;
  return v === "1" || v.toLowerCase() === "true" || v.toLowerCase() === "yes";
}

@Injectable()
export class StorageService implements OnModuleInit {
  private readonly log = new Logger(StorageService.name);
  private internalClient: Client;
  private signerClient: Client;
  private ensuredBuckets = new Set<string>();
  private enabled: boolean;

  onModuleInit() {
    const publicBase = (process.env.MINIO_PUBLIC_BASE_URL ?? "").trim();
    if (!this.enabled) return;
    if (!publicBase) {
      this.log.warn(
        "MINIO_PUBLIC_BASE_URL не задан: presigned URL будут с хостом MINIO_ENDPOINT (часто minio:9000) — браузер их не откроет. Укажи публичный URL того же nginx, где проксируются /shop-products и т.д. (см. infra/nginx/default.conf).",
      );
    }
  }

  constructor() {
    const endPoint = process.env.MINIO_ENDPOINT ?? "minio";
    const port = Number(process.env.MINIO_PORT ?? "9000");
    const useSSL = toBool(process.env.MINIO_USE_SSL, false);
    const { accessKey, secretKey } = this.resolveMinioCredentials();
    this.enabled = Boolean(accessKey && secretKey);

    this.internalClient = new Client({
      endPoint,
      port,
      useSSL,
      accessKey,
      secretKey,
      region: "us-east-1",
    });

    const publicBase = (process.env.MINIO_PUBLIC_BASE_URL ?? "").trim();
    if (!publicBase) {
      // Fallback: sign using internal endpoint (useful only if client can reach it).
      this.signerClient = this.internalClient;
    } else {
      const u = new URL(publicBase);
      this.signerClient = new Client({
        endPoint: u.hostname,
        port: Number(u.port || (u.protocol === "https:" ? "443" : "80")),
        useSSL: u.protocol === "https:",
        accessKey,
        secretKey,
        region: "us-east-1",
      });
    }
  }

  private resolveMinioCredentials(): { accessKey: string; secretKey: string } {
    const rootUser = (process.env.MINIO_ROOT_USER ?? "minioadmin").trim();
    const rootPass = (process.env.MINIO_ROOT_PASSWORD ?? "").trim();
    let accessKey = (process.env.MINIO_ACCESS_KEY ?? rootUser).trim();
    let secretKey = (process.env.MINIO_SECRET_KEY ?? rootPass).trim();

    // generate_fresh_env.sh used to emit a random MINIO_SECRET_KEY unrelated to root password.
    if (accessKey === rootUser && rootPass && secretKey !== rootPass) {
      this.log.warn(
        "MINIO_SECRET_KEY не совпадает с MINIO_ROOT_PASSWORD для root access key — используем MINIO_ROOT_PASSWORD",
      );
      secretKey = rootPass;
    }

    return { accessKey, secretKey };
  }

  private assertEnabled() {
    if (!this.enabled) {
      throw new BadRequestException("MinIO не настроен (MINIO_ACCESS_KEY/MINIO_SECRET_KEY)");
    }
  }

  private async ensureBucket(bucket: string) {
    this.assertEnabled();
    if (this.ensuredBuckets.has(bucket)) return;
    const exists = await this.internalClient.bucketExists(bucket).catch(() => false);
    if (!exists) {
      await this.internalClient.makeBucket(bucket, "us-east-1");
    }
    this.ensuredBuckets.add(bucket);
  }

  /**
   * Распознаёт логическое имя корзины из тела запроса (camelCase из Flutter).
   */
  normalizeLogicalBucket(raw: unknown): BucketName | null {
    if (raw === undefined || raw === null) return null;
    const s =
      typeof raw === "string"
        ? raw.trim().toLowerCase()
        : String(raw).trim().toLowerCase();
    if (!s) return null;
    if (s === "quest-evidence" || s === "questevidence") return "quest-evidence";
    if (s === "shop-products" || s === "shopproducts") return "shop-products";
    if (
      s === "member-avatars" ||
      s === "memberavatars" ||
      s === "member_avatars" ||
      s === "avatars"
    ) {
      return "member-avatars";
    }
    return null;
  }

  logicalBucketToPhysical(name: BucketName): string {
    if (name === "quest-evidence") return process.env.MINIO_BUCKET_QUEST_EVIDENCE ?? "quest-evidence";
    if (name === "shop-products") return process.env.MINIO_BUCKET_SHOP_PRODUCTS ?? "shop-products";
    return process.env.MINIO_BUCKET_MEMBER_AVATARS ?? "member-avatars";
  }

  requireLogicalBucket(raw: unknown): BucketName {
    const logical = this.normalizeLogicalBucket(raw);
    if (logical != null) return logical;
    if (raw === undefined || raw === null || (typeof raw === "string" && !raw.trim())) {
      throw new BadRequestException(
        "Не указано поле bucket. Для аватаров используйте member-avatars (поле объекта bucket в JSON).",
      );
    }
    throw new BadRequestException(
      `Неизвестная корзина: ${JSON.stringify(String(raw))}. Разрешены: quest-evidence, shop-products, member-avatars.`,
    );
  }

  async presignUpload(bucketName: unknown, objectKey: string, expiresSeconds: number) {
    this.assertEnabled();
    const logical = this.requireLogicalBucket(bucketName);
    const bucket = this.logicalBucketToPhysical(logical);
    const key = objectKey.trim();
    if (!key) throw new BadRequestException("objectKey обязателен");
    await this.ensureBucket(bucket);
    const exp = Math.min(Math.max(60, Math.trunc(expiresSeconds || 300)), 3600);
    const url = await this.signerClient.presignedPutObject(bucket, key, exp);
    return { bucket, objectKey: key, url, expiresSeconds: exp };
  }

  async presignDownload(bucketName: unknown, objectKey: string, expiresSeconds: number) {
    this.assertEnabled();
    const logical = this.requireLogicalBucket(bucketName);
    const bucket = this.logicalBucketToPhysical(logical);
    const key = objectKey.trim();
    if (!key) throw new BadRequestException("objectKey обязателен");
    await this.ensureBucket(bucket);
    const exp = Math.min(Math.max(60, Math.trunc(expiresSeconds || 300)), 3600);
    const url = await this.signerClient.presignedGetObject(bucket, key, exp);
    return { bucket, objectKey: key, url, expiresSeconds: exp };
  }

  async uploadBuffer(bucketName: unknown, objectKey: string, buffer: Buffer, contentType: string) {
    this.assertEnabled();
    const logical = this.requireLogicalBucket(bucketName);
    const bucket = this.logicalBucketToPhysical(logical);
    const key = objectKey.trim();
    if (!key) throw new BadRequestException("objectKey обязателен");
    await this.ensureBucket(bucket);
    await this.internalClient.putObject(
      bucket,
      key,
      buffer,
      buffer.length,
      { "Content-Type": contentType || "application/octet-stream" },
    );
    return { bucket, objectKey: key };
  }
}

