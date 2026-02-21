import { serviceClient } from "../_shared/supabase.ts";

async function sendTelegram(chatId: string, text: string) {
  const token = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
  if (!token) return;
  await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text }),
  });
}

async function sendPush(_token: string, _title: string, _body: string) {
  // Production: integrate FCM/APNS provider here.
  return;
}

Deno.serve(async (_req) => {
  try {
    const supabase = serviceClient();
    const now = new Date();
    const inThreeDays = new Date(now);
    inThreeDays.setDate(inThreeDays.getDate() + 3);

    const { data: expiring } = await supabase
      .from("family_subscriptions")
      .select("family_id, plan_code, expires_at, families(owner_user_id)")
      .eq("status", "active")
      .lte("expires_at", inThreeDays.toISOString())
      .gte("expires_at", now.toISOString());

    for (const row of expiring ?? []) {
      const ownerUserId = (row as Record<string, unknown>)["families"] as
        | Record<string, unknown>
        | null;
      const toUserId = ownerUserId?.["owner_user_id"]?.toString() ?? null;
      await supabase.from("notifications").insert({
        family_id: row.family_id,
        to_user_id: toUserId,
        n_type: "subscription_expiring",
        payload: {
          plan: row.plan_code,
          expires_at: row.expires_at,
        },
      });

      const { data: tgLinks } = await supabase
        .from("telegram_links")
        .select("telegram_chat_id")
        .eq("family_id", row.family_id);
      for (const tg of tgLinks ?? []) {
        await sendTelegram(
          tg.telegram_chat_id,
          `Подписка ${row.plan_code} скоро закончится (${row.expires_at})`,
        );
      }
    }

    const { data: devices } = await supabase
      .from("notification_devices")
      .select("push_token")
      .eq("is_active", true)
      .limit(500);
    for (const device of devices ?? []) {
      await sendPush(device.push_token, "Klany", "Проверь новые уведомления в приложении");
    }

    return Response.json({ ok: true, processed: expiring?.length ?? 0 });
  } catch (error) {
    return Response.json({ ok: false, error: (error as Error).message }, { status: 500 });
  }
});

