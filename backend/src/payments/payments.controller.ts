import { Body, Controller, Post, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";
import { PaymentsService } from "./payments.service";

@Controller()
@UseGuards(AuthGuard("jwt"), RolesGuard)
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Post("payments/orders")
  @Roles("parent", "admin")
  async createOrder(
    @Req() req: any,
    @Body() body: { planCode: string; amountRub: number },
  ) {
    return this.payments.createOrder(req.user, body);
  }

  @Post("payments/yookassa/create-payment")
  @Roles("parent", "admin")
  async createYookassa(@Req() req: any, @Body() body: { orderId: string }) {
    return this.payments.createYookassaPayment(req.user, body.orderId);
  }
}

