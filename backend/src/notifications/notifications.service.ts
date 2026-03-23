import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { PrismaService } from '../prisma/prisma.service';
import { ApnsService } from './apns.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly apns: ApnsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  // --- Helper: get partner info for notifications ---

  private async getPartnerInfo(pairId: string, senderUserId: string) {
    const pair = await this.prisma.pair.findUnique({ where: { id: pairId } });
    if (!pair) return null;

    const partnerUserId = pair.userAId === senderUserId ? pair.userBId : pair.userAId;
    if (!partnerUserId) return null;

    const partner = await this.prisma.user.findUnique({
      where: { id: partnerUserId },
      select: { id: true, apnsToken: true, displayName: true },
    });

    return partner;
  }

  private async getSenderName(userId: string): Promise<string> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { displayName: true },
    });
    return user?.displayName || 'Your partner';
  }

  private async notifyPartner(
    pairId: string,
    senderUserId: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ) {
    const partner = await this.getPartnerInfo(pairId, senderUserId);
    if (!partner) return;

    // Only send push if partner is NOT connected via WebSocket
    if (!this.realtime.isUserOnline(partner.id) && partner.apnsToken) {
      await this.apns.send(partner.apnsToken, title, body, data);
    }
  }

  private async notifyBothUsers(
    pairId: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ) {
    const pair = await this.prisma.pair.findUnique({ where: { id: pairId } });
    if (!pair) return;

    for (const userId of [pair.userAId, pair.userBId].filter(Boolean) as string[]) {
      if (!this.realtime.isUserOnline(userId)) {
        const user = await this.prisma.user.findUnique({
          where: { id: userId },
          select: { apnsToken: true },
        });
        if (user?.apnsToken) {
          await this.apns.send(user.apnsToken, title, body, data);
        }
      }
    }
  }

  // --- 1. New vault fact (Cloud Function: onNewVaultFact) ---

  @OnEvent('vault.created')
  async onVaultCreated(payload: { pairId: string; fact: any; userId: string }) {
    const senderName = await this.getSenderName(payload.userId);
    await this.notifyPartner(
      payload.pairId,
      payload.userId,
      'New Vault Entry',
      `${senderName} added something to your vault`,
      { type: 'vault', pairId: payload.pairId },
    );
  }

  // --- 2. New list item (Cloud Function: onNewListItem) ---

  @OnEvent('item.created')
  async onItemCreated(payload: { pairId: string; item: any; userId: string }) {
    const senderName = await this.getSenderName(payload.userId);
    await this.notifyPartner(
      payload.pairId,
      payload.userId,
      'New Idea Added',
      `${senderName} added a date idea: ${payload.item.title}`,
      { type: 'listItem', pairId: payload.pairId },
    );
  }

  // --- 3. Session started (Cloud Function: onSessionStarted) ---

  @OnEvent('session.created')
  async onSessionCreated(payload: { pairId: string; session: any; userId: string }) {
    const senderName = await this.getSenderName(payload.userId);
    await this.notifyPartner(
      payload.pairId,
      payload.userId,
      'Swipe Time!',
      `${senderName} wants to decide — swipe time!`,
      { type: 'session', pairId: payload.pairId },
    );
  }

  // --- 4. Swipe match detected (Cloud Function: onSessionUpdated - match part) ---

  @OnEvent('session.updated')
  async onSessionUpdated(payload: {
    pairId: string;
    session: any;
    newMatch?: boolean;
    swipedItemId?: string;
    userId?: string;
  }) {
    if (!payload.newMatch || !payload.swipedItemId) return;

    // Look up the matched item title
    const item = await this.prisma.listItem.findUnique({
      where: { id: payload.swipedItemId },
      select: { title: true },
    });

    const title = item?.title || 'something';

    // Notify BOTH users about the match
    await this.notifyBothUsers(
      payload.pairId,
      "It's a Match!",
      `You both want: ${title}`,
      { type: 'match', pairId: payload.pairId },
    );
  }

  // --- 5. New availability (Cloud Function: onNewAvailability) ---

  @OnEvent('availability.created')
  async onAvailabilityCreated(payload: { pairId: string; slot: any; userId: string }) {
    const senderName = await this.getSenderName(payload.userId);
    await this.notifyPartner(
      payload.pairId,
      payload.userId,
      'Schedule Updated',
      `${senderName} updated their schedule`,
      { type: 'availability', pairId: payload.pairId },
    );
  }

  // --- 6. New event proposed (Cloud Function: onNewEvent) ---

  @OnEvent('event.created')
  async onEventCreated(payload: { pairId: string; event: any; userId: string }) {
    const senderName = await this.getSenderName(payload.userId);
    await this.notifyPartner(
      payload.pairId,
      payload.userId,
      'Date Proposed!',
      `${senderName} proposed a date: ${payload.event.title}`,
      { type: 'event', pairId: payload.pairId },
    );
  }
}
