import * as bcrypt from "bcrypt";

import { PrismaClient } from "@prisma/client";

function mustEnv(key: string): string {
  const v = (process.env[key] ?? "").trim();
  if (!v) throw new Error(`Missing env: ${key}`);
  return v;
}

async function main() {
  const email = mustEnv("ADMIN_SEED_EMAIL").toLowerCase();
  const password = mustEnv("ADMIN_SEED_PASSWORD");

  const prisma = new PrismaClient();
  try {
    const passwordHash = await bcrypt.hash(password, 10);

    const user = await prisma.user.upsert({
      where: { email },
      create: { email, passwordHash },
      update: { passwordHash },
      select: { id: true, email: true },
    });

    await prisma.profile.upsert({
      where: { userId: user.id },
      create: { userId: user.id, role: "admin", familyId: null, displayName: "Admin" },
      update: { role: "admin" },
      select: { userId: true },
    });

    // eslint-disable-next-line no-console
    console.log(`[seed-admin] ok: ${user.email} -> role=admin`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error("[seed-admin] failed:", e);
  process.exit(1);
});

