import "reflect-metadata";

import { NestFactory } from "@nestjs/core";

import { AppModule } from "./app.module";

function buildCorsOptions(): {
  origin:
    | boolean
    | ((
        origin: string | undefined,
        cb: (err: Error | null, allow?: boolean) => void,
      ) => void);
  methods: string[];
  allowedHeaders: string[];
  exposedHeaders: string[];
  credentials: boolean;
  maxAge: number;
} {
  const raw = process.env.CORS_ORIGIN_ALLOWLIST?.trim();
  const list = raw
    ? raw
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean)
    : [];

  // Пустой allowlist → отражаем Origin запроса (Flutter web с localhost / любой домен).
  // Для жёсткого prod: CORS_ORIGIN_ALLOWLIST=https://klanymobail.ru,http://localhost:55374
  if (list.length === 0) {
    return {
      origin: true,
      methods: ["GET", "HEAD", "PUT", "PATCH", "POST", "DELETE", "OPTIONS"],
      allowedHeaders: [
        "Authorization",
        "Content-Type",
        "Accept",
        "X-Requested-With",
      ],
      exposedHeaders: ["Content-Length", "Content-Type"],
      credentials: process.env.CORS_CREDENTIALS === "true",
      maxAge: 86400,
    };
  }

  return {
    origin: (origin, cb) => {
      if (!origin) {
        cb(null, true);
        return;
      }
      cb(null, list.includes(origin));
    },
    methods: ["GET", "HEAD", "PUT", "PATCH", "POST", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Authorization",
      "Content-Type",
      "Accept",
      "X-Requested-With",
    ],
    exposedHeaders: ["Content-Length", "Content-Type"],
    credentials: process.env.CORS_CREDENTIALS === "true",
    maxAge: 86400,
  };
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors(buildCorsOptions());
  // Keep all HTTP endpoints under /api/* (matches nginx and mobile API_BASE_URL).
  app.setGlobalPrefix("api");
  await app.listen(Number(process.env.PORT ?? 3000), "0.0.0.0");
}

void bootstrap();

