import { serviceClient } from "../_shared/supabase.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type CreatePaymentBody = {
  orderId: string;
};

const port = Number(Deno.env.get("PORT") ?? "8000");

Deno.serve({ port }, async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: CORS_HEADERS });
  }

  try {
    const body = (await req.json()) as CreatePaymentBody;
    if (!body?.orderId) {
      return Response.json({ error: "orderId is required" }, { status: 400, headers: CORS_HEADERS });
    }

    const shopId = Deno.env.get("YOOKASSA_SHOP_ID") ?? "";
    const secret = Deno.env.get("YOOKASSA_SECRET_KEY") ?? "";
    const returnUrl = Deno.env.get("YOOKASSA_RETURN_URL") ?? "";
    if (!shopId || !secret || !returnUrl) {
      return Response.json(
        { error: "YooKassa env vars are not configured" },
        { status: 500, headers: CORS_HEADERS },
      );
    }

    const supabase = serviceClient();
    const { data: order, error: orderError } = await supabase
      .from("payment_orders")
      .select("id, amount_rub, family_id, plan_code, status")
      .eq("id", body.orderId)
      .maybeSingle();

    if (orderError || !order) {
      return Response.json({ error: "Order not found" }, { status: 404, headers: CORS_HEADERS });
    }

    const amountValue = Number(order.amount_rub).toFixed(2);
    const idempotenceKey = crypto.randomUUID();
    const auth = btoa(`${shopId}:${secret}`);

    const yookassaResponse = await fetch("https://api.yookassa.ru/v3/payments", {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        "Idempotence-Key": idempotenceKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: { value: amountValue, currency: "RUB" },
        capture: true,
        confirmation: {
          type: "redirect",
          return_url: returnUrl,
        },
        description: `Klany subscription order ${order.id}`,
        metadata: {
          order_id: order.id,
          family_id: order.family_id,
          plan_code: order.plan_code,
        },
      }),
    });

    const yookassaData = await yookassaResponse.json();
    if (!yookassaResponse.ok) {
      return Response.json({ error: yookassaData }, { status: 502, headers: CORS_HEADERS });
    }

    await supabase
      .from("payment_orders")
      .update({
        provider_payment_id: yookassaData.id,
        payload: yookassaData,
      })
      .eq("id", order.id);

    return Response.json(
      {
        orderId: order.id,
        paymentId: yookassaData.id,
        confirmationUrl: yookassaData.confirmation?.confirmation_url,
      },
      { headers: CORS_HEADERS },
    );
  } catch (error) {
    return Response.json(
      { error: (error as Error).message },
      { status: 500, headers: CORS_HEADERS },
    );
  }
});

