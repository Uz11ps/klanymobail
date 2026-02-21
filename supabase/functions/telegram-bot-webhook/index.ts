import { serviceClient } from "../_shared/supabase.ts";

function textResponse(message: string) {
  return { method: "sendMessage", text: message };
}

async function sendTelegram(chatId: string, text: string) {
  const token = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
  if (!token) return;
  await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text }),
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const update = await req.json();
    const message = update?.message;
    const text: string = (message?.text ?? "").trim();
    const chatId = String(message?.chat?.id ?? "");
    const username = message?.from?.username as string | undefined;

    if (!chatId || !text) return Response.json({ ok: true });
    const supabase = serviceClient();

    if (text === "/start") {
      await sendTelegram(
        chatId,
        "Привет! Команды:\n/link FAMILY-ID — привязать чат к семье\n/promo CODE — активировать промокод",
      );
      return Response.json({ ok: true, ...textResponse("ok") });
    }

    if (text.startsWith("/link ")) {
      const familyCode = text.replace("/link", "").trim();
      const { data: family } = await supabase
        .from("families")
        .select("id")
        .ilike("family_code", familyCode)
        .maybeSingle();

      if (!family) {
        await sendTelegram(chatId, "Family ID не найден");
        return Response.json({ ok: true });
      }

      await supabase
        .from("telegram_links")
        .upsert({
          family_id: family.id,
          telegram_chat_id: chatId,
          telegram_username: username ?? null,
        }, { onConflict: "telegram_chat_id" });

      await sendTelegram(chatId, "Чат привязан к семье. Теперь можно активировать промокоды.");
      return Response.json({ ok: true });
    }

    if (text.startsWith("/promo ")) {
      const code = text.replace("/promo", "").trim().toUpperCase();
      const { data: link } = await supabase
        .from("telegram_links")
        .select("family_id")
        .eq("telegram_chat_id", chatId)
        .maybeSingle();
      if (!link) {
        await sendTelegram(chatId, "Сначала привяжите семью командой /link FAMILY-ID");
        return Response.json({ ok: true });
      }

      const { data: promo } = await supabase
        .from("promo_codes")
        .select("id, plan_code, duration_days, max_uses, used_count, is_active")
        .eq("code", code)
        .maybeSingle();

      if (!promo || promo.is_active !== true || promo.used_count >= promo.max_uses) {
        await sendTelegram(chatId, "Промокод недоступен");
        return Response.json({ ok: true });
      }

      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + Math.max(Number(promo.duration_days || 30), 1));

      await supabase.from("family_subscriptions").insert({
        family_id: link.family_id,
        plan_code: promo.plan_code,
        status: "active",
        started_at: new Date().toISOString(),
        expires_at: expiresAt.toISOString(),
        source: "telegram_promo",
      });

      await supabase
        .from("promo_codes")
        .update({ used_count: Number(promo.used_count || 0) + 1 })
        .eq("id", promo.id);

      await supabase.from("promo_redemptions").insert({
        promo_id: promo.id,
        family_id: link.family_id,
      });

      await sendTelegram(chatId, `Промокод применён. Тариф: ${promo.plan_code}`);
      return Response.json({ ok: true });
    }

    await sendTelegram(chatId, "Неизвестная команда. Используйте /start");
    return Response.json({ ok: true });
  } catch (error) {
    return Response.json({ ok: false, error: (error as Error).message }, { status: 500 });
  }
});

