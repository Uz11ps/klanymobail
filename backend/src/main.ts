import "reflect-metadata";

import { NestFactory } from "@nestjs/core";

import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { cors: true });
  // Keep all HTTP endpoints under /api/* (matches nginx and mobile API_BASE_URL).
  app.setGlobalPrefix("api");
  await app.listen(Number(process.env.PORT ?? 3000), "0.0.0.0");
}

void bootstrap();

