-- Add unique constraint for notification_devices.pushToken
CREATE UNIQUE INDEX "notification_devices_pushToken_key" ON "notification_devices"("pushToken");

