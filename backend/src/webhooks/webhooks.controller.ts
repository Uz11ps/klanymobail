import { Body, Controller, Post, Req } from "@nestjs/common";

import { WebhooksService } from "./webhooks.service";

@Controller()
export class WebhooksController {
  constructor(private readonly webhooks: WebhooksService) {}

  @Post("webhooks/yookassa")
  async yookassa(@Body() payload: any) {
    return this.webhooks.handleYookassa(payload);
  }

  @Post("webhooks/telegram")
  async telegram(@Body() update: any) {
    return this.webhooks.handleTelegram(update);
  }
}

