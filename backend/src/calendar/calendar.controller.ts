import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Query,
  Body,
  UseGuards,
} from '@nestjs/common';
import { CalendarService } from './calendar.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PairMemberGuard } from '../pairs/guards/pair-member.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import {
  CreateAvailabilityDto,
  UpdateAvailabilityDto,
  CreateEventDto,
  UpdateEventDto,
  RespondEventDto,
} from './dto/calendar.dto';

@Controller('pairs/:pairId')
@UseGuards(JwtAuthGuard, PairMemberGuard)
export class CalendarController {
  constructor(private readonly calendarService: CalendarService) {}

  // --- Availability ---

  @Get('availability')
  async findAllSlots(
    @Param('pairId') pairId: string,
    @Query('month') month?: string,
  ) {
    return this.calendarService.findAllSlots(pairId, month);
  }

  @Post('availability')
  async createSlot(
    @Param('pairId') pairId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateAvailabilityDto,
  ) {
    return this.calendarService.createSlot(pairId, user.sub, dto);
  }

  @Patch('availability/:slotId')
  async updateSlot(
    @Param('pairId') pairId: string,
    @Param('slotId') slotId: string,
    @Body() dto: UpdateAvailabilityDto,
  ) {
    return this.calendarService.updateSlot(pairId, slotId, dto);
  }

  @Delete('availability/:slotId')
  async deleteSlot(
    @Param('pairId') pairId: string,
    @Param('slotId') slotId: string,
  ) {
    return this.calendarService.deleteSlot(pairId, slotId);
  }

  // --- Events ---

  @Get('events')
  async findAllEvents(@Param('pairId') pairId: string) {
    return this.calendarService.findAllEvents(pairId);
  }

  @Post('events')
  async createEvent(
    @Param('pairId') pairId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateEventDto,
  ) {
    return this.calendarService.createEvent(pairId, user.sub, dto);
  }

  @Patch('events/:eventId')
  async updateEvent(
    @Param('pairId') pairId: string,
    @Param('eventId') eventId: string,
    @Body() dto: UpdateEventDto,
  ) {
    return this.calendarService.updateEvent(pairId, eventId, dto);
  }

  @Post('events/:eventId/respond')
  async respondToEvent(
    @Param('pairId') pairId: string,
    @Param('eventId') eventId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: RespondEventDto,
  ) {
    return this.calendarService.respondToEvent(pairId, eventId, user.sub, dto);
  }

  @Delete('events/:eventId')
  async deleteEvent(
    @Param('pairId') pairId: string,
    @Param('eventId') eventId: string,
  ) {
    return this.calendarService.deleteEvent(pairId, eventId);
  }
}
