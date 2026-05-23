import { Injectable, Logger } from "@nestjs/common";

export type SendMailInput = {
  to: string;
  subject: string;
  html: string;
};

@Injectable()
export class ResendMailService {
  private readonly log = new Logger(ResendMailService.name);

  isConfigured(): boolean {
    return Boolean((process.env.RESEND_API_KEY ?? "").trim());
  }

  async send(input: SendMailInput): Promise<{ ok: boolean; skipped?: boolean; id?: string }> {
    const apiKey = (process.env.RESEND_API_KEY ?? "").trim();
    if (!apiKey) {
      this.log.warn("RESEND_API_KEY не задан — письмо не отправлено");
      return { ok: false, skipped: true };
    }

    const from = (process.env.RESEND_FROM_EMAIL ?? "onboarding@resend.dev").trim();
    const to = input.to.trim().toLowerCase();
    if (!to.includes("@")) {
      this.log.warn(`Некорректный адрес получателя: ${to}`);
      return { ok: false, skipped: true };
    }

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [to],
        subject: input.subject,
        html: input.html,
      }),
    });

    if (!res.ok) {
      const body = await res.text().catch(() => "");
      this.log.error(`Resend HTTP ${res.status}: ${body}`);
      return { ok: false };
    }

    const json = (await res.json().catch(() => ({}))) as { id?: string };
    return { ok: true, id: json.id };
  }
}
