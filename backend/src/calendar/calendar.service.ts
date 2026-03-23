import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  CreateAvailabilityDto,
  UpdateAvailabilityDto,
  CreateEventDto,
  UpdateEventDto,
  RespondEventDto,
} from './dto/calendar.dto';

@Injectable()
export class CalendarService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  // --- Availability ---

  async findAllSlots(pairId: string, month?: string) {
    const where: any = { pairId };
    if (month) {
      // month is "yyyy-MM", filter by date range
      const start = new Date(`${month}-01`);
      const end = new Date(start);
      end.setMonth(end.getMonth() + 1);
      where.date = { gte: start, lt: end };
    }
    return this.prisma.availabilitySlot.findMany({
      where,
      orderBy: { date: 'asc' },
    });
  }

  async createSlot(pairId: string, userId: string, dto: CreateAvailabilityDto) {
    const dateObj = new Date(dto.date + 'T00:00:00Z');

    // Upsert: if slot already exists for this user+date, update it
    const existing = await this.prisma.availabilitySlot.findUnique({
      where: {
        pairId_userId_date: { pairId, userId, date: dateObj },
      },
    });

    if (existing) {
      const updated = await this.prisma.availabilitySlot.update({
        where: { id: existing.id },
        data: {
          startTime: dto.startTime,
          endTime: dto.endTime,
          label: dto.label,
        },
      });
      this.events.emit('availability.updated', { pairId, slot: updated });
      return updated;
    }

    const slot = await this.prisma.availabilitySlot.create({
      data: {
        pairId,
        userId,
        date: dateObj,
        startTime: dto.startTime,
        endTime: dto.endTime,
        label: dto.label,
      },
    });

    this.events.emit('availability.created', { pairId, slot, userId });
    return slot;
  }

  async updateSlot(pairId: string, slotId: string, dto: UpdateAvailabilityDto) {
    const existing = await this.prisma.availabilitySlot.findFirst({
      where: { id: slotId, pairId },
    });
    if (!existing) throw new NotFoundException('Slot not found');

    const slot = await this.prisma.availabilitySlot.update({
      where: { id: slotId },
      data: {
        ...(dto.startTime !== undefined && { startTime: dto.startTime }),
        ...(dto.endTime !== undefined && { endTime: dto.endTime }),
        ...(dto.label !== undefined && { label: dto.label }),
      },
    });

    this.events.emit('availability.updated', { pairId, slot });
    return slot;
  }

  async deleteSlot(pairId: string, slotId: string) {
    const existing = await this.prisma.availabilitySlot.findFirst({
      where: { id: slotId, pairId },
    });
    if (!existing) throw new NotFoundException('Slot not found');

    await this.prisma.availabilitySlot.delete({ where: { id: slotId } });

    this.events.emit('availability.deleted', { pairId, slotId });
    return { success: true };
  }

  // --- Events ---

  async findAllEvents(pairId: string) {
    return this.prisma.calendarEvent.findMany({
      where: { pairId },
      orderBy: { startDate: 'asc' },
    });
  }

  async createEvent(pairId: string, userId: string, dto: CreateEventDto) {
    const event = await this.prisma.calendarEvent.create({
      data: {
        pairId,
        createdById: userId,
        title: dto.title,
        description: dto.description,
        startDate: new Date(dto.startDate + 'T00:00:00Z'),
        endDate: new Date(dto.endDate + 'T00:00:00Z'),
        startTime: dto.startTime,
        endTime: dto.endTime,
        status: 'pending',
      },
    });

    this.events.emit('event.created', { pairId, event, userId });
    return event;
  }

  async updateEvent(pairId: string, eventId: string, dto: UpdateEventDto) {
    const existing = await this.prisma.calendarEvent.findFirst({
      where: { id: eventId, pairId },
    });
    if (!existing) throw new NotFoundException('Event not found');

    const data: any = {};
    if (dto.title !== undefined) data.title = dto.title;
    if (dto.description !== undefined) data.description = dto.description;
    if (dto.startDate !== undefined) data.startDate = new Date(dto.startDate + 'T00:00:00Z');
    if (dto.endDate !== undefined) data.endDate = new Date(dto.endDate + 'T00:00:00Z');
    if (dto.startTime !== undefined) data.startTime = dto.startTime;
    if (dto.endTime !== undefined) data.endTime = dto.endTime;

    const event = await this.prisma.calendarEvent.update({
      where: { id: eventId },
      data,
    });

    this.events.emit('event.updated', { pairId, event });
    return event;
  }

  async respondToEvent(pairId: string, eventId: string, userId: string, dto: RespondEventDto) {
    const existing = await this.prisma.calendarEvent.findFirst({
      where: { id: eventId, pairId },
    });
    if (!existing) throw new NotFoundException('Event not found');

    const event = await this.prisma.calendarEvent.update({
      where: { id: eventId },
      data: {
        status: dto.accepted ? 'accepted' : 'declined',
        declineReason: dto.reason,
        respondedAt: new Date(),
      },
    });

    // If accepted, create availability slots for each day in the event range
    if (dto.accepted) {
      await this.createSlotsForEventRange(pairId, userId, event);
    }

    this.events.emit('event.updated', { pairId, event });
    return event;
  }

  async deleteEvent(pairId: string, eventId: string) {
    const existing = await this.prisma.calendarEvent.findFirst({
      where: { id: eventId, pairId },
    });
    if (!existing) throw new NotFoundException('Event not found');

    await this.prisma.calendarEvent.delete({ where: { id: eventId } });

    this.events.emit('event.deleted', { pairId, eventId });
    return { success: true };
  }

  // --- Helpers ---

  private async createSlotsForEventRange(
    pairId: string,
    userId: string,
    event: { startDate: Date; endDate: Date; startTime: string | null; endTime: string | null; title: string },
  ) {
    const current = new Date(event.startDate);
    const end = new Date(event.endDate);

    while (current <= end) {
      const dateObj = new Date(current);

      // Only create if user doesn't already have a slot for this date
      const exists = await this.prisma.availabilitySlot.findUnique({
        where: {
          pairId_userId_date: { pairId, userId, date: dateObj },
        },
      });

      if (!exists) {
        await this.prisma.availabilitySlot.create({
          data: {
            pairId,
            userId,
            date: dateObj,
            startTime: event.startTime,
            endTime: event.endTime,
            label: event.title,
          },
        });
      }

      current.setDate(current.getDate() + 1);
    }
  }
}
