import { serviceClient } from "../_shared/supabase.ts";

function addDays(base: Date, days: number): Date {
  const d = new Date(base);
  d.setDate(d.getDate() + days);
  return d;
}

const port = Number(Deno.env.get("PORT") ?? "8000");

Deno.serve({ port }, async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const payload = await req.json();
    const eventType = payload?.event as string | undefined;
    const payment = payload?.object;
    const paymentId = payment?.id as string | undefined;
    const metadata = payment?.metadata ?? {};
    const orderId = metadata?.order_id as string | undefined;

    const supabase = serviceClient();
    await supabase.from("payment_webhook_events").insert({
      provider: "yookassa",
      event_type: eventType ?? "unknown",
      event_id: paymentId ?? null,
      payload,
      processed: false,
    });

    if (eventType !== "payment.succeeded" || !orderId) {
      return Response.json({ ok: true, skipped: true });
    }

    const { data: order } = await supabase
      .from("payment_orders")
      .select("id, family_id, plan_code, status")
      .eq("id", orderId)
      .maybeSingle();

    if (!order) {
      return Response.json({ ok: false, error: "Order not found" }, { status: 404 });
    }

    await supabase
      .from("payment_orders")
      .update({
        status: "paid",
        paid_at: new Date().toISOString(),
        payload,
      })
      .eq("id", order.id);

    await supabase.from("family_subscriptions").insert({
      family_id: order.family_id,
      plan_code: order.plan_code ?? "premium",
      status: "active",
      started_at: new Date().toISOString(),
      expires_at: addDays(new Date(), 30).toISOString(),
      source: "yookassa",
    });

    await supabase
      .from("payment_webhook_events")
      .update({ processed: true })
      .eq("event_id", paymentId ?? "");

    return Response.json({ ok: true });
  } catch (error) {
    return Response.json({ ok: false, error: (error as Error).message }, { status: 500 });
  }
});

