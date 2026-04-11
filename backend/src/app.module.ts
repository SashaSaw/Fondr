import { Module } from '@nestjs/common';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { ScheduleModule } from '@nestjs/schedule';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { PairsModule } from './pairs/pairs.module';
import { VaultModule } from './vault/vault.module';
import { ListsModule } from './lists/lists.module';
import { SessionsModule } from './sessions/sessions.module';
import { CalendarModule } from './calendar/calendar.module';
import { OurStoryModule } from './our-story/our-story.module';
import { TmdbModule } from './tmdb/tmdb.module';
import { StorageModule } from './storage/storage.module';
import { RealtimeModule } from './realtime/realtime.module';
import { NotificationsModule } from './notifications/notifications.module';

@Module({
  imports: [
    EventEmitterModule.forRoot(),
    ScheduleModule.forRoot(),
    PrismaModule,
    AuthModule,
    UsersModule,
    PairsModule,
    VaultModule,
    ListsModule,
    SessionsModule,
    CalendarModule,
    OurStoryModule,
    TmdbModule,
    StorageModule,
    RealtimeModule,
    NotificationsModule,
  ],
})
export class AppModule {}
