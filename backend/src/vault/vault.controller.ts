import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import { VaultService } from './vault.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PairMemberGuard } from '../pairs/guards/pair-member.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { CreateVaultFactDto, UpdateVaultFactDto } from './dto/vault.dto';

@Controller('pairs/:pairId/vault')
@UseGuards(JwtAuthGuard, PairMemberGuard)
export class VaultController {
  constructor(private readonly vaultService: VaultService) {}

  @Get()
  async findAll(@Param('pairId') pairId: string) {
    return this.vaultService.findAll(pairId);
  }

  @Post()
  async create(
    @Param('pairId') pairId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateVaultFactDto,
  ) {
    return this.vaultService.create(pairId, user.sub, dto);
  }

  @Patch(':factId')
  async update(
    @Param('pairId') pairId: string,
    @Param('factId') factId: string,
    @Body() dto: UpdateVaultFactDto,
  ) {
    return this.vaultService.update(pairId, factId, dto);
  }

  @Delete(':factId')
  async delete(
    @Param('pairId') pairId: string,
    @Param('factId') factId: string,
  ) {
    return this.vaultService.delete(pairId, factId);
  }
}
