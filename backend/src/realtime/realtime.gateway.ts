import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server } from 'ws';
import { JwtService } from '@nestjs/jwt';
import { OnEvent } from '@nestjs/event-emitter';
import { PrismaService } from '../prisma/prisma.service';
import { IncomingMessage } from 'http';

interface AuthedWebSocket {
  userId?: string;
  pairId?: string | null;
  isAlive?: boolean;
  send(data: string): void;
  on(event: string, listener: (...args: any[]) => void): void;
  terminate(): void;
  close(): void;
  readyState: number;
}

@WebSocketGateway({ path: '/ws' })
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private connectedUsers = new Map<string, Set<AuthedWebSocket>>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async handleConnection(client: AuthedWebSocket, req: IncomingMessage) {
    try {
      // Extract token from query string
      const url = new URL(req.url || '', 'http://localhost');
      const token = url.searchParams.get('token');

      if (!token) {
        client.close();
        return;
      }

      const payload = this.jwtService.verify(token);
      const userId = payload.sub;

      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, pairId: true },
      });

      if (!user) {
        client.close();
        return;
      }

      client.userId = userId;
      client.pairId = user.pairId;
      client.isAlive = true;

      if (!this.connectedUsers.has(userId)) {
        this.connectedUsers.set(userId, new Set());
      }
      this.connectedUsers.get(userId)!.add(client);

      // Heartbeat
      client.on('message', (data: any) => {
        const msg = data.toString();
        if (msg === 'ping') {
          client.send('pong');
        }
        client.isAlive = true;
      });

      client.on('pong', () => {
        client.isAlive = true;
      });

    } catch {
      client.close();
    }
  }

  handleDisconnect(client: AuthedWebSocket) {
    const userId = client.userId;
    if (userId) {
      const sockets = this.connectedUsers.get(userId);
      if (sockets) {
        sockets.delete(client);
        if (sockets.size === 0) {
          this.connectedUsers.delete(userId);
        }
      }
    }
  }

  isUserOnline(userId: string): boolean {
    const sockets = this.connectedUsers.get(userId);
    return !!sockets && sockets.size > 0;
  }

  // --- Broadcast to pair room ---

  private broadcastToPair(pairId: string, event: string, data: any) {
    const message = JSON.stringify({ event, data });
    for (const [, sockets] of this.connectedUsers) {
      for (const socket of sockets) {
        if (socket.pairId === pairId && socket.readyState === 1) {
          socket.send(message);
        }
      }
    }
  }

  // --- Pair events ---

  @OnEvent('pair.updated')
  handlePairUpdated(payload: { pair: any }) {
    this.broadcastToPair(payload.pair.id, 'pair:updated', payload.pair);
  }

  @OnEvent('pair.activated')
  handlePairActivated(payload: { pair: any }) {
    this.broadcastToPair(payload.pair.id, 'pair:updated', payload.pair);
  }

  // --- Vault events ---

  @OnEvent('vault.created')
  handleVaultCreated(payload: { pairId: string; fact: any }) {
    this.broadcastToPair(payload.pairId, 'vault:created', payload.fact);
  }

  @OnEvent('vault.updated')
  handleVaultUpdated(payload: { pairId: string; fact: any }) {
    this.broadcastToPair(payload.pairId, 'vault:updated', payload.fact);
  }

  @OnEvent('vault.deleted')
  handleVaultDeleted(payload: { pairId: string; factId: string }) {
    this.broadcastToPair(payload.pairId, 'vault:deleted', { id: payload.factId });
  }

  // --- List events ---

  @OnEvent('list.created')
  handleListCreated(payload: { pairId: string; list: any }) {
    this.broadcastToPair(payload.pairId, 'list:created', payload.list);
  }

  @OnEvent('list.updated')
  handleListUpdated(payload: { pairId: string; list: any }) {
    this.broadcastToPair(payload.pairId, 'list:updated', payload.list);
  }

  @OnEvent('list.deleted')
  handleListDeleted(payload: { pairId: string; listId: string }) {
    this.broadcastToPair(payload.pairId, 'list:deleted', { id: payload.listId });
  }

  // --- Item events ---

  @OnEvent('item.created')
  handleItemCreated(payload: { pairId: string; item: any }) {
    this.broadcastToPair(payload.pairId, 'item:created', payload.item);
  }

  @OnEvent('item.updated')
  handleItemUpdated(payload: { pairId: string; item: any }) {
    this.broadcastToPair(payload.pairId, 'item:updated', payload.item);
  }

  @OnEvent('item.deleted')
  handleItemDeleted(payload: { pairId: string; itemId: string }) {
    this.broadcastToPair(payload.pairId, 'item:deleted', { id: payload.itemId });
  }

  // --- Session events ---

  @OnEvent('session.created')
  handleSessionCreated(payload: { pairId: string; session: any }) {
    this.broadcastToPair(payload.pairId, 'session:created', payload.session);
  }

  @OnEvent('session.updated')
  handleSessionUpdated(payload: { pairId: string; session: any }) {
    this.broadcastToPair(payload.pairId, 'session:updated', payload.session);
  }

  @OnEvent('session.deleted')
  handleSessionDeleted(payload: { pairId: string; sessionId: string }) {
    this.broadcastToPair(payload.pairId, 'session:deleted', { id: payload.sessionId });
  }

  // --- Availability events ---

  @OnEvent('availability.created')
  handleAvailabilityCreated(payload: { pairId: string; slot: any }) {
    this.broadcastToPair(payload.pairId, 'availability:created', payload.slot);
  }

  @OnEvent('availability.updated')
  handleAvailabilityUpdated(payload: { pairId: string; slot: any }) {
    this.broadcastToPair(payload.pairId, 'availability:updated', payload.slot);
  }

  @OnEvent('availability.deleted')
  handleAvailabilityDeleted(payload: { pairId: string; slotId: string }) {
    this.broadcastToPair(payload.pairId, 'availability:deleted', { id: payload.slotId });
  }

  // --- Calendar event events ---

  @OnEvent('event.created')
  handleEventCreated(payload: { pairId: string; event: any }) {
    this.broadcastToPair(payload.pairId, 'event:created', payload.event);
  }

  @OnEvent('event.updated')
  handleEventUpdated(payload: { pairId: string; event: any }) {
    this.broadcastToPair(payload.pairId, 'event:updated', payload.event);
  }

  @OnEvent('event.deleted')
  handleEventDeleted(payload: { pairId: string; eventId: string }) {
    this.broadcastToPair(payload.pairId, 'event:deleted', { id: payload.eventId });
  }

  // --- Significant date events ---

  @OnEvent('significant-date.created')
  handleSignificantDateCreated(payload: { pairId: string; significantDate: any }) {
    this.broadcastToPair(payload.pairId, 'significant-date:created', payload.significantDate);
  }

  @OnEvent('significant-date.updated')
  handleSignificantDateUpdated(payload: { pairId: string; significantDate: any }) {
    this.broadcastToPair(payload.pairId, 'significant-date:updated', payload.significantDate);
  }

  @OnEvent('significant-date.deleted')
  handleSignificantDateDeleted(payload: { pairId: string; dateId: string }) {
    this.broadcastToPair(payload.pairId, 'significant-date:deleted', { id: payload.dateId });
  }
}
