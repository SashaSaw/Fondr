import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { pair: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const { passwordHash, refreshToken, ...safe } = user;
    return safe;
  }

  async updateMe(userId: string, dto: UpdateUserDto) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: dto,
    });
    const { passwordHash, refreshToken, ...safe } = user;
    return safe;
  }

  async updateApnsToken(userId: string, token: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { apnsToken: token },
    });
    return { success: true };
  }

  async deleteMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { pairId: true },
    });

    if (user?.pairId) {
      // Notify partner before deleting
      this.events.emit('pair.deleted', { pairId: user.pairId });

      // Clear partner references
      await this.prisma.user.updateMany({
        where: { pairId: user.pairId },
        data: { pairId: null, partnerId: null },
      });

      // Delete pair (cascades related data)
      await this.prisma.pair.delete({ where: { id: user.pairId } });
    }

    // Delete the user
    await this.prisma.user.delete({ where: { id: userId } });
    return { success: true };
  }
}
