import { Global, Module } from "@nestjs/common";

import { ResendMailService } from "./resend-mail.service";

@Global()
@Module({
  providers: [ResendMailService],
  exports: [ResendMailService],
})
export class MailModule {}
