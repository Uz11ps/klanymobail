import { Body, Controller, Get, Param, Post, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";
import { ShopService } from "./shop.service";

@Controller()
@UseGuards(AuthGuard("jwt"), RolesGuard)
export class ShopController {
  constructor(private readonly shop: ShopService) {}

  @Get("shop/products")
  @Roles("parent", "admin", "child")
  async listProducts(@Req() req: any) {
    return this.shop.listProducts(req.user);
  }

  @Post("shop/products")
  @Roles("parent", "admin")
  async createProduct(
    @Req() req: any,
    @Body() body: { title: string; description?: string; price: number; imageKey?: string | null },
  ) {
    return this.shop.createProduct(req.user, body);
  }

  @Post("shop/products/:id/toggle")
  @Roles("parent", "admin")
  async toggle(@Req() req: any, @Param("id") id: string, @Body() body: { isActive: boolean }) {
    return this.shop.toggleProduct(req.user, id, body.isActive);
  }

  @Post("shop/purchases/request")
  @Roles("child")
  async requestPurchase(@Req() req: any, @Body() body: { productId: string; quantity?: number }) {
    return this.shop.requestPurchase(req.user, body.productId, body.quantity ?? 1);
  }

  @Get("shop/purchases/pending")
  @Roles("parent", "admin")
  async pending(@Req() req: any) {
    return this.shop.listPending(req.user);
  }

  @Post("shop/purchases/:id/decide")
  @Roles("parent", "admin")
  async decide(@Req() req: any, @Param("id") id: string, @Body() body: { approve: boolean }) {
    return this.shop.decide(req.user, id, body.approve);
  }
}

