import { BadRequestException, Injectable } from "@nestjs/common";
import { Client } from "minio";

type BucketName = "quest-evidence" | "shop-products";

function toBool(v: string | undefined, def: boolean): boolean {
  if (v == null) return def;
  return v === "1" || v.toLowerCase() === "true" || v.toLowerCase() === "yes";
}

@Injectable()
export class StorageService {
  private internalClient: Client;
  private signerClient: Client;
  private ensuredBuckets = new Set<string>();

  constructor() {
    const endPoint = process.env.MINIO_ENDPOINT ?? "minio";
    const port = Number(process.env.MINIO_PORT ?? "9000");
    const useSSL = toBool(process.env.MINIO_USE_SSL, false);
    const accessKey = process.env.MINIO_ACCESS_KEY ?? process.env.MINIO_ROOT_USER ?? "";
    const secretKey = process.env.MINIO_SECRET_KEY ?? process.env.MINIO_ROOT_PASSWORD ?? "";
    if (!accessKey || !secretKey) {
      // MinIO is optional in dev, but endpoints will fail with clear error.
    }

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

  private async ensureBucket(bucket: string) {
    if (this.ensuredBuckets.has(bucket)) return;
    const exists = await this.internalClient.bucketExists(bucket).catch(() => false);
    if (!exists) {
      await this.internalClient.makeBucket(bucket, "us-east-1");
    }
    this.ensuredBuckets.add(bucket);
  }

  resolveBucket(name: BucketName): string {
    if (name === "quest-evidence") return process.env.MINIO_BUCKET_QUEST_EVIDENCE ?? "quest-evidence";
    if (name === "shop-products") return process.env.MINIO_BUCKET_SHOP_PRODUCTS ?? "shop-products";
    throw new BadRequestException("Unknown bucket");
  }

  async presignUpload(bucketName: BucketName, objectKey: string, expiresSeconds: number) {
    const bucket = this.resolveBucket(bucketName);
    const key = objectKey.trim();
    if (!key) throw new BadRequestException("objectKey обязателен");
    await this.ensureBucket(bucket);
    const exp = Math.min(Math.max(60, Math.trunc(expiresSeconds || 300)), 3600);
    const url = await this.signerClient.presignedPutObject(bucket, key, exp);
    return { bucket, objectKey: key, url, expiresSeconds: exp };
  }

  async presignDownload(bucketName: BucketName, objectKey: string, expiresSeconds: number) {
    const bucket = this.resolveBucket(bucketName);
    const key = objectKey.trim();
    if (!key) throw new BadRequestException("objectKey обязателен");
    await this.ensureBucket(bucket);
    const exp = Math.min(Math.max(60, Math.trunc(expiresSeconds || 300)), 3600);
    const url = await this.signerClient.presignedGetObject(bucket, key, exp);
    return { bucket, objectKey: key, url, expiresSeconds: exp };
  }

  async uploadBuffer(bucketName: BucketName, objectKey: string, buffer: Buffer, contentType: string) {
    const bucket = this.resolveBucket(bucketName);
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

