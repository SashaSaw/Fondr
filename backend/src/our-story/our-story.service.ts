import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { CreateSignificantDateDto, UpdateSignificantDateDto } from './dto/our-story.dto';

@Injectable()
export class OurStoryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  async findAll(pairId: string) {
    return this.prisma.significantDate.findMany({
      where: { pairId },
      orderBy: { date: 'asc' },
    });
  }

  async create(pairId: string, userId: string, dto: CreateSignificantDateDto) {
    const sigDate = await this.prisma.significantDate.create({
      data: {
        pairId,
        addedById: userId,
        title: dto.title,
        date: new Date(dto.date + 'T00:00:00Z'),
        emoji: dto.emoji,
        recurring: dto.recurring,
      },
    });

    this.events.emit('significant-date.created', { pairId, significantDate: sigDate });
    return sigDate;
  }

  async update(pairId: string, dateId: string, dto: UpdateSignificantDateDto) {
    const existing = await this.prisma.significantDate.findFirst({
      where: { id: dateId, pairId },
    });
    if (!existing) throw new NotFoundException('Significant date not found');

    const data: any = {};
    if (dto.title !== undefined) data.title = dto.title;
    if (dto.date !== undefined) data.date = new Date(dto.date + 'T00:00:00Z');
    if (dto.emoji !== undefined) data.emoji = dto.emoji;
    if (dto.recurring !== undefined) data.recurring = dto.recurring;

    const sigDate = await this.prisma.significantDate.update({
      where: { id: dateId },
      data,
    });

    this.events.emit('significant-date.updated', { pairId, significantDate: sigDate });
    return sigDate;
  }

  async delete(pairId: string, dateId: string) {
    const existing = await this.prisma.significantDate.findFirst({
      where: { id: dateId, pairId },
    });
    if (!existing) throw new NotFoundException('Significant date not found');

    await this.prisma.significantDate.delete({ where: { id: dateId } });

    this.events.emit('significant-date.deleted', { pairId, dateId });
    return { success: true };
  }
}
