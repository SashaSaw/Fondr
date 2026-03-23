import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

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
}
