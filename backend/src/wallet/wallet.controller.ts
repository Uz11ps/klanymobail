import { Body, Controller, Get, Post, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";
import { WalletService } from "./wallet.service";

@Controller()
@UseGuards(AuthGuard("jwt"), RolesGuard)
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  @Get("wallet/child")
  @Roles("child")
  async childWallet(@Req() req: any) {
    return this.wallet.getChildWallet(req.user);
  }

  @Get("wallet/child/transactions")
  @Roles("child")
  async childTx(@Req() req: any) {
    return this.wallet.getChildTransactions(req.user);
  }

  @Get("wallet/family")
  @Roles("parent", "admin")
  async familyWallets(@Req() req: any) {
    return this.wallet.getFamilyWallets(req.user);
  }

  @Post("wallet/adjust")
  @Roles("parent", "admin")
  async adjust(
    @Req() req: any,
    @Body() body: { childId: string; amount: number; note?: string },
  ) {
    return this.wallet.adjust(req.user, body);
  }
}

