import {
  Controller,
  Get,
  Patch,
  Put,
  Post,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { UsersService } from './users.service';
import { StorageService } from '../storage/storage.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { UpdateUserDto, UpdateApnsTokenDto } from './dto/update-user.dto';
import { PrismaService } from '../prisma/prisma.service';
import { EventEmitter2 } from '@nestjs/event-emitter';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly storageService: StorageService,
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  @Get('me')
  async getMe(@CurrentUser() user: JwtPayload) {
    return this.usersService.getMe(user.sub);
  }

  @Patch('me')
  async updateMe(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateUserDto,
  ) {
    return this.usersService.updateMe(user.sub, dto);
  }

  @Put('me/apns-token')
  async updateApnsToken(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateApnsTokenDto,
  ) {
    return this.usersService.updateApnsToken(user.sub, dto.token);
  }

  @Post('me/profile-image')
  @UseInterceptors(FileInterceptor('image', { limits: { fileSize: 5 * 1024 * 1024 } }))
  async uploadProfileImage(
    @CurrentUser() user: JwtPayload,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const url = await this.storageService.uploadProfileImage(user.sub, file);

    // Notify partner of photo change via pair update
    const updatedUser = await this.usersService.getMe(user.sub);
    if (updatedUser.pairId) {
      const pair = await this.prisma.pair.findUnique({
        where: { id: updatedUser.pairId },
        include: {
          userA: { select: { id: true, displayName: true, profileImageUrl: true, timezone: true } },
          userB: { select: { id: true, displayName: true, profileImageUrl: true, timezone: true } },
        },
      });
      if (pair) {
        this.events.emit('pair.updated', { pair });
      }
    }

    return { profileImageUrl: url };
  }
}
