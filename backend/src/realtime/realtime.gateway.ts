import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { OnEvent } from '@nestjs/event-emitter';
import { PrismaService } from '../prisma/prisma.service';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/',
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  // Track which users are connected (userId -> Set<socketId>)
  private connectedUsers = new Map<string, Set<string>>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token =
        client.handshake.auth?.token ||
        client.handshake.headers?.authorization?.replace('Bearer ', '');

      if (!token) {
        client.disconnect();
        return;
      }

      const payload = this.jwtService.verify(token);
      const userId = payload.sub;

      // Look up user's pair
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, pairId: true },
      });

      if (!user) {
        client.disconnect();
        return;
      }

      // Store userId on the socket for later use
      (client as any).userId = userId;
      (client as any).pairId = user.pairId;

      // Track connection
      if (!this.connectedUsers.has(userId)) {
        this.connectedUsers.set(userId, new Set());
      }
      this.connectedUsers.get(userId)!.add(client.id);

      // Join pair room if user is in a pair
      if (user.pairId) {
        client.join(`pair:${user.pairId}`);
      }
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const userId = (client as any).userId;
    if (userId) {
      const sockets = this.connectedUsers.get(userId);
      if (sockets) {
        sockets.delete(client.id);
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

  // --- Pair events ---

  @OnEvent('pair.updated')
  handlePairUpdated(payload: { pair: any }) {
    this.server.to(`pair:${payload.pair.id}`).emit('pair:updated', payload.pair);
  }

  @OnEvent('pair.activated')
  handlePairActivated(payload: { pair: any }) {
    this.server.to(`pair:${payload.pair.id}`).emit('pair:updated', payload.pair);
  }

  // --- Vault events ---

  @OnEvent('vault.created')
  handleVaultCreated(payload: { pairId: string; fact: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('vault:created', payload.fact);
  }

  @OnEvent('vault.updated')
  handleVaultUpdated(payload: { pairId: string; fact: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('vault:updated', payload.fact);
  }

  @OnEvent('vault.deleted')
  handleVaultDeleted(payload: { pairId: string; factId: string }) {
    this.server.to(`pair:${payload.pairId}`).emit('vault:deleted', { id: payload.factId });
  }

  // --- List events ---

  @OnEvent('list.created')
  handleListCreated(payload: { pairId: string; list: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('list:created', payload.list);
  }

  @OnEvent('list.updated')
  handleListUpdated(payload: { pairId: string; list: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('list:updated', payload.list);
  }

  @OnEvent('list.deleted')
  handleListDeleted(payload: { pairId: string; listId: string }) {
    this.server.to(`pair:${payload.pairId}`).emit('list:deleted', { id: payload.listId });
  }

  // --- Item events ---

  @OnEvent('item.created')
  handleItemCreated(payload: { pairId: string; item: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('item:created', payload.item);
  }

  @OnEvent('item.updated')
  handleItemUpdated(payload: { pairId: string; item: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('item:updated', payload.item);
  }

  @OnEvent('item.deleted')
  handleItemDeleted(payload: { pairId: string; itemId: string }) {
    this.server.to(`pair:${payload.pairId}`).emit('item:deleted', { id: payload.itemId });
  }

  // --- Session events ---

  @OnEvent('session.created')
  handleSessionCreated(payload: { pairId: string; session: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('session:created', payload.session);
  }

  @OnEvent('session.updated')
  handleSessionUpdated(payload: { pairId: string; session: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('session:updated', payload.session);
  }

  @OnEvent('session.deleted')
  handleSessionDeleted(payload: { pairId: string; sessionId: string }) {
    this.server.to(`pair:${payload.pairId}`).emit('session:deleted', { id: payload.sessionId });
  }

  // --- Availability events ---

  @OnEvent('availability.created')
  handleAvailabilityCreated(payload: { pairId: string; slot: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('availability:created', payload.slot);
  }

  @OnEvent('availability.updated')
  handleAvailabilityUpdated(payload: { pairId: string; slot: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('availability:updated', payload.slot);
  }

  @OnEvent('availability.deleted')
  handleAvailabilityDeleted(payload: { pairId: string; slotId: string }) {
    this.server.to(`pair:${payload.pairId}`).emit('availability:deleted', { id: payload.slotId });
  }

  // --- Calendar event events ---

  @OnEvent('event.created')
  handleEventCreated(payload: { pairId: string; event: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('event:created', payload.event);
  }

  @OnEvent('event.updated')
  handleEventUpdated(payload: { pairId: string; event: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('event:updated', payload.event);
  }

  @OnEvent('event.deleted')
  handleEventDeleted(payload: { pairId: string; eventId: string }) {
    this.server.to(`pair:${payload.pairId}`).emit('event:deleted', { id: payload.eventId });
  }

  // --- Significant date events ---

  @OnEvent('significant-date.created')
  handleSignificantDateCreated(payload: { pairId: string; significantDate: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('significant-date:created', payload.significantDate);
  }

  @OnEvent('significant-date.updated')
  handleSignificantDateUpdated(payload: { pairId: string; significantDate: any }) {
    this.server.to(`pair:${payload.pairId}`).emit('significant-date:updated', payload.significantDate);
  }

  @OnEvent('significant-date.deleted')
  handleSignificantDateDeleted(payload: { pairId: string; dateId: string }) {
    this.server.to(`pair:${payload.pairId}`).emit('significant-date:deleted', { id: payload.dateId });
  }
}
