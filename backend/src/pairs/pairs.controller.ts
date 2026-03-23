import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { PairsService } from './pairs.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PairMemberGuard } from './guards/pair-member.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { JoinPairDto, UpdatePairDto } from './dto/pairs.dto';

@Controller('pairs')
@UseGuards(JwtAuthGuard)
export class PairsController {
  constructor(private readonly pairsService: PairsService) {}

  @Post()
  async create(@CurrentUser() user: JwtPayload) {
    return this.pairsService.create(user.sub);
  }

  @Post('join')
  async join(
    @CurrentUser() user: JwtPayload,
    @Body() dto: JoinPairDto,
  ) {
    return this.pairsService.join(user.sub, dto.inviteCode);
  }

  @Get(':pairId')
  @UseGuards(PairMemberGuard)
  async get(@Param('pairId') pairId: string) {
    return this.pairsService.get(pairId);
  }

  @Patch(':pairId')
  @UseGuards(PairMemberGuard)
  async update(
    @Param('pairId') pairId: string,
    @Body() dto: UpdatePairDto,
  ) {
    return this.pairsService.update(pairId, dto.anniversary);
  }

  @Delete(':pairId')
  @UseGuards(PairMemberGuard)
  async delete(@Param('pairId') pairId: string) {
    return this.pairsService.delete(pairId);
  }
}
