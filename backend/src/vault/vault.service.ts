import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { CreateVaultFactDto, UpdateVaultFactDto } from './dto/vault.dto';

@Injectable()
export class VaultService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  async findAll(pairId: string) {
    return this.prisma.vaultFact.findMany({
      where: { pairId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(pairId: string, userId: string, dto: CreateVaultFactDto) {
    const fact = await this.prisma.vaultFact.create({
      data: {
        pairId,
        addedById: userId,
        category: dto.category,
        label: dto.label,
        value: dto.value,
      },
    });

    this.events.emit('vault.created', { pairId, fact, userId });
    return fact;
  }

  async update(pairId: string, factId: string, dto: UpdateVaultFactDto) {
    const fact = await this.prisma.vaultFact.findFirst({
      where: { id: factId, pairId },
    });
    if (!fact) throw new NotFoundException('Vault fact not found');

    const updated = await this.prisma.vaultFact.update({
      where: { id: factId },
      data: {
        ...(dto.label !== undefined && { label: dto.label }),
        ...(dto.value !== undefined && { value: dto.value }),
      },
    });

    this.events.emit('vault.updated', { pairId, fact: updated });
    return updated;
  }

  async delete(pairId: string, factId: string) {
    const fact = await this.prisma.vaultFact.findFirst({
      where: { id: factId, pairId },
    });
    if (!fact) throw new NotFoundException('Vault fact not found');

    await this.prisma.vaultFact.delete({ where: { id: factId } });

    this.events.emit('vault.deleted', { pairId, factId });
    return { success: true };
  }
}
