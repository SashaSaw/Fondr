import { Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { ApnsService } from './apns.service';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [RealtimeModule],
  providers: [NotificationsService, ApnsService],
  exports: [NotificationsService, ApnsService],
})
export class NotificationsModule {}
