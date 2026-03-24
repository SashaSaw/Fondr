import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EventEmitter2 } from '@nestjs/event-emitter';

function generateInviteCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

@Injectable()
export class PairsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  async create(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (user.pairId) throw new ConflictException('Already in a pair');

    let inviteCode: string;
    let attempts = 0;
    do {
      inviteCode = generateInviteCode();
      const existing = await this.prisma.pair.findUnique({
        where: { inviteCode },
      });
      if (!existing) break;
      attempts++;
    } while (attempts < 10);

    if (attempts >= 10) {
      throw new BadRequestException('Could not generate unique invite code');
    }

    const pair = await this.prisma.pair.create({
      data: {
        userAId: userId,
        inviteCode,
        status: 'pending',
      },
    });

    await this.prisma.user.update({
      where: { id: userId },
      data: { pairId: pair.id },
    });

    return pair;
  }

  async join(userId: string, inviteCode: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (user.pairId) throw new ConflictException('Already in a pair');

    const pair = await this.prisma.pair.findUnique({
      where: { inviteCode },
    });

    if (!pair || pair.status !== 'pending') {
      throw new NotFoundException('Invalid or expired invite code');
    }

    if (pair.userAId === userId) {
      throw new BadRequestException('Cannot join your own pair');
    }

    const updatedPair = await this.prisma.pair.update({
      where: { id: pair.id },
      data: {
        userBId: userId,
        status: 'active',
      },
    });

    // Update both users
    await this.prisma.user.update({
      where: { id: userId },
      data: { pairId: pair.id, partnerId: pair.userAId },
    });
    await this.prisma.user.update({
      where: { id: pair.userAId },
      data: { partnerId: userId },
    });

    const fullPair = await this.prisma.pair.findUnique({
      where: { id: pair.id },
      include: {
        userA: { select: { id: true, displayName: true, profileImageUrl: true, timezone: true } },
        userB: { select: { id: true, displayName: true, profileImageUrl: true, timezone: true } },
      },
    });
    this.events.emit('pair.activated', { pair: fullPair });

    return fullPair;
  }

  async update(pairId: string, anniversary?: string) {
    const data: Record<string, unknown> = {};
    if (anniversary) {
      data.anniversary = new Date(anniversary);
    }

    await this.prisma.pair.update({
      where: { id: pairId },
      data,
    });

    const pair = await this.prisma.pair.findUnique({
      where: { id: pairId },
      include: {
        userA: { select: { id: true, displayName: true, profileImageUrl: true, timezone: true } },
        userB: { select: { id: true, displayName: true, profileImageUrl: true, timezone: true } },
      },
    });

    this.events.emit('pair.updated', { pair });
    return pair;
  }

  async delete(pairId: string) {
    const pair = await this.prisma.pair.findUnique({
      where: { id: pairId },
    });
    if (!pair) throw new NotFoundException('Pair not found');

    // Clear user references
    await this.prisma.user.updateMany({
      where: { pairId },
      data: { pairId: null, partnerId: null },
    });

    // Delete pair (cascades subcollection data)
    await this.prisma.pair.delete({ where: { id: pairId } });

    return { success: true };
  }

  async get(pairId: string) {
    const pair = await this.prisma.pair.findUnique({
      where: { id: pairId },
      include: {
        userA: {
          select: { id: true, displayName: true, profileImageUrl: true, timezone: true },
        },
        userB: {
          select: { id: true, displayName: true, profileImageUrl: true, timezone: true },
        },
      },
    });
    if (!pair) throw new NotFoundException('Pair not found');
    return pair;
  }
}
