import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { StartSessionDto, SwipeDto, ChooseMatchDto } from './dto/sessions.dto';

@Injectable()
export class SessionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  async getActive(pairId: string) {
    const sessions = await this.prisma.swipeSession.findMany({
      where: { pairId, status: 'active' },
      orderBy: { createdAt: 'asc' },
    });

    // Clean up stale sessions (>24h old)
    const staleThreshold = new Date(Date.now() - 24 * 60 * 60 * 1000);
    for (const session of sessions) {
      if (session.createdAt < staleThreshold) {
        await this.prisma.swipeSession.delete({ where: { id: session.id } });
      }
    }

    return sessions.find((s) => s.createdAt >= staleThreshold) || null;
  }

  async getHistory(pairId: string, limit = 10) {
    return this.prisma.swipeSession.findMany({
      where: { pairId, status: 'complete' },
      orderBy: { completedAt: 'desc' },
      take: limit,
    });
  }

  async start(pairId: string, userId: string, dto: StartSessionDto) {
    // Get suggested/matched items for this list (exclude done)
    const items = await this.prisma.listItem.findMany({
      where: {
        pairId,
        listId: dto.listId,
        status: { not: 'done' },
      },
    });

    if (items.length < 3) {
      throw new BadRequestException('Need at least 3 items to start a session');
    }

    // Reset any matched items back to suggested
    const matchedIds = items.filter((i) => i.status === 'matched').map((i) => i.id);
    if (matchedIds.length > 0) {
      await this.prisma.listItem.updateMany({
        where: { id: { in: matchedIds } },
        data: { status: 'suggested' },
      });
    }

    // Shuffle item IDs
    const itemIds = items.map((i) => i.id);
    for (let i = itemIds.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [itemIds[i], itemIds[j]] = [itemIds[j], itemIds[i]];
    }

    const session = await this.prisma.swipeSession.create({
      data: {
        pairId,
        listId: dto.listId,
        itemIds,
        swipesA: {},
        swipesB: {},
        matches: [],
        status: 'active',
        startedById: userId,
      },
    });

    this.events.emit('session.created', { pairId, session, userId });
    return session;
  }

  async swipe(pairId: string, sessionId: string, userId: string, dto: SwipeDto) {
    // Use raw SQL for row-level locking to prevent race conditions
    const result = await this.prisma.$transaction(async (tx) => {
      // Lock the row
      const rows = await tx.$queryRawUnsafe<any[]>(
        `SELECT * FROM swipe_sessions WHERE id = $1 AND pair_id = $2 FOR UPDATE`,
        sessionId,
        pairId,
      );

      if (!rows || rows.length === 0) {
        throw new NotFoundException('Session not found');
      }

      const session = rows[0];
      if (session.status !== 'active') {
        throw new BadRequestException('Session is not active');
      }

      // Determine if user is A or B
      const pair = await tx.pair.findUnique({ where: { id: pairId } });
      if (!pair) throw new NotFoundException('Pair not found');

      const isUserA = userId === pair.userAId;
      const swipesA: Record<string, string> = session.swipes_a as Record<string, string>;
      const swipesB: Record<string, string> = session.swipes_b as Record<string, string>;

      // Record swipe
      if (isUserA) {
        swipesA[dto.itemId] = dto.direction;
      } else {
        swipesB[dto.itemId] = dto.direction;
      }

      // Check for match
      const matches: string[] = session.matches as string[];
      const otherSwipes = isUserA ? swipesB : swipesA;
      let newMatch = false;

      if (dto.direction === 'right' && otherSwipes[dto.itemId] === 'right') {
        matches.push(dto.itemId);
        newMatch = true;

        // Update list item status to matched
        await tx.listItem.update({
          where: { id: dto.itemId },
          data: { status: 'matched' },
        });
      }

      // Check if both users are done
      const itemIds: string[] = session.item_ids as string[];
      const allDone =
        Object.keys(swipesA).length === itemIds.length &&
        Object.keys(swipesB).length === itemIds.length;

      const updateData: any = {
        swipesA,
        swipesB,
        matches,
      };

      if (allDone) {
        updateData.status = 'complete';
        updateData.completedAt = new Date();
      }

      const updated = await tx.swipeSession.update({
        where: { id: sessionId },
        data: updateData,
      });

      return { session: updated, newMatch };
    });

    this.events.emit('session.updated', {
      pairId,
      session: result.session,
      newMatch: result.newMatch,
      swipedItemId: dto.itemId,
      userId,
    });

    return result.session;
  }

  async choose(pairId: string, sessionId: string, dto: ChooseMatchDto) {
    const session = await this.prisma.swipeSession.findFirst({
      where: { id: sessionId, pairId },
    });
    if (!session) throw new NotFoundException('Session not found');

    const updated = await this.prisma.swipeSession.update({
      where: { id: sessionId },
      data: { chosenItemId: dto.chosenItemId },
    });

    // Revert non-chosen matches back to suggested
    const revertIds = dto.allMatchIds.filter((id) => id !== dto.chosenItemId);
    if (revertIds.length > 0) {
      await this.prisma.listItem.updateMany({
        where: { id: { in: revertIds } },
        data: { status: 'suggested' },
      });
    }

    this.events.emit('session.updated', { pairId, session: updated });
    return updated;
  }

  async discard(pairId: string, sessionId: string) {
    const session = await this.prisma.swipeSession.findFirst({
      where: { id: sessionId, pairId },
    });
    if (!session) throw new NotFoundException('Session not found');

    await this.prisma.swipeSession.delete({ where: { id: sessionId } });

    this.events.emit('session.deleted', { pairId, sessionId });
    return { success: true };
  }
}
