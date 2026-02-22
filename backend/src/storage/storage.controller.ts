import { Body, Controller, Post, Query, Req, UploadedFile, UseGuards, UseInterceptors } from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import { AuthGuard } from "@nestjs/passport";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";
import { StorageService } from "./storage.service";

@Controller()
@UseGuards(AuthGuard("jwt"), RolesGuard)
export class StorageController {
  constructor(private readonly storage: StorageService) {}

  @Post("storage/presign-upload")
  @Roles("parent", "admin", "child")
  async presignUpload(
    @Body() body: { bucket: "quest-evidence" | "shop-products"; objectKey: string; expiresSeconds?: number },
  ) {
    return this.storage.presignUpload(body.bucket, body.objectKey, body.expiresSeconds ?? 300);
  }

  @Post("storage/presign-download")
  @Roles("parent", "admin", "child")
  async presignDownload(
    @Body() body: { bucket: "quest-evidence" | "shop-products"; objectKey: string; expiresSeconds?: number },
  ) {
    return this.storage.presignDownload(body.bucket, body.objectKey, body.expiresSeconds ?? 300);
  }

  // Fallback: upload via API (multipart/form-data) -> MinIO.
  @Post("storage/upload")
  @Roles("parent", "admin", "child")
  @UseInterceptors(FileInterceptor("file"))
  async upload(
    @UploadedFile() file: Express.Multer.File,
    @Query("bucket") bucket: "quest-evidence" | "shop-products",
    @Query("objectKey") objectKey: string,
  ) {
    const ct = file?.mimetype || "application/octet-stream";
    const buf = file?.buffer;
    return this.storage.uploadBuffer(bucket, objectKey, buf, ct);
  }
}

