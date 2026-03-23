import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { CreateListDto, UpdateListDto, CreateItemDto, UpdateItemDto } from './dto/lists.dto';

const DEFAULT_LISTS = [
  { title: 'Date Ideas', emoji: '💡', subtitle: 'Things to do together', sortOrder: 0 },
  { title: 'Watch Together', emoji: '🍿', subtitle: 'Movies, shows & more', sortOrder: 1 },
];

@Injectable()
export class ListsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  // --- SharedList CRUD ---

  async findAllLists(pairId: string) {
    return this.prisma.sharedList.findMany({
      where: { pairId },
      orderBy: { sortOrder: 'asc' },
    });
  }

  async createList(pairId: string, userId: string, dto: CreateListDto) {
    const count = await this.prisma.sharedList.count({ where: { pairId } });

    const list = await this.prisma.sharedList.create({
      data: {
        pairId,
        createdById: userId,
        title: dto.title,
        emoji: dto.emoji,
        subtitle: dto.subtitle,
        sortOrder: count,
      },
    });

    this.events.emit('list.created', { pairId, list });
    return list;
  }

  async updateList(pairId: string, listId: string, dto: UpdateListDto) {
    const existing = await this.prisma.sharedList.findFirst({
      where: { id: listId, pairId },
    });
    if (!existing) throw new NotFoundException('List not found');

    const list = await this.prisma.sharedList.update({
      where: { id: listId },
      data: {
        ...(dto.title !== undefined && { title: dto.title }),
        ...(dto.emoji !== undefined && { emoji: dto.emoji }),
        ...(dto.subtitle !== undefined && { subtitle: dto.subtitle }),
        ...(dto.sortOrder !== undefined && { sortOrder: dto.sortOrder }),
      },
    });

    this.events.emit('list.updated', { pairId, list });
    return list;
  }

  async deleteList(pairId: string, listId: string) {
    const existing = await this.prisma.sharedList.findFirst({
      where: { id: listId, pairId },
    });
    if (!existing) throw new NotFoundException('List not found');

    // Cascade delete handles items via Prisma relation
    await this.prisma.sharedList.delete({ where: { id: listId } });

    this.events.emit('list.deleted', { pairId, listId });
    return { success: true };
  }

  async seedDefaultLists(pairId: string, userId: string) {
    const existing = await this.prisma.sharedList.count({ where: { pairId } });
    if (existing > 0) return;

    for (const def of DEFAULT_LISTS) {
      await this.prisma.sharedList.create({
        data: {
          pairId,
          createdById: userId,
          title: def.title,
          emoji: def.emoji,
          subtitle: def.subtitle,
          sortOrder: def.sortOrder,
        },
      });
    }
  }

  // --- ListItem CRUD ---

  async findAllItems(pairId: string, listId?: string) {
    return this.prisma.listItem.findMany({
      where: {
        pairId,
        ...(listId && { listId }),
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createItem(pairId: string, userId: string, dto: CreateItemDto) {
    const item = await this.prisma.listItem.create({
      data: {
        pairId,
        listId: dto.listId,
        addedById: userId,
        title: dto.title,
        description: dto.description,
        imageUrl: dto.imageUrl,
        status: 'suggested',
        metadataTmdbId: dto.metadataTmdbId,
        metadataYear: dto.metadataYear,
        metadataGenre: dto.metadataGenre,
        metadataRating: dto.metadataRating,
        metadataRuntime: dto.metadataRuntime,
      },
    });

    this.events.emit('item.created', { pairId, item, userId });
    return item;
  }

  async updateItem(pairId: string, itemId: string, dto: UpdateItemDto) {
    const existing = await this.prisma.listItem.findFirst({
      where: { id: itemId, pairId },
    });
    if (!existing) throw new NotFoundException('Item not found');

    const item = await this.prisma.listItem.update({
      where: { id: itemId },
      data: {
        ...(dto.title !== undefined && { title: dto.title }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.status !== undefined && { status: dto.status }),
        ...(dto.completionNote !== undefined && { completionNote: dto.completionNote }),
      },
    });

    this.events.emit('item.updated', { pairId, item });
    return item;
  }

  async deleteItem(pairId: string, itemId: string) {
    const existing = await this.prisma.listItem.findFirst({
      where: { id: itemId, pairId },
    });
    if (!existing) throw new NotFoundException('Item not found');

    await this.prisma.listItem.delete({ where: { id: itemId } });

    this.events.emit('item.deleted', { pairId, itemId });
    return { success: true };
  }
}
