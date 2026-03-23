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
import { OurStoryService } from './our-story.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PairMemberGuard } from '../pairs/guards/pair-member.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { CreateSignificantDateDto, UpdateSignificantDateDto } from './dto/our-story.dto';

@Controller('pairs/:pairId/significant-dates')
@UseGuards(JwtAuthGuard, PairMemberGuard)
export class OurStoryController {
  constructor(private readonly ourStoryService: OurStoryService) {}

  @Get()
  async findAll(@Param('pairId') pairId: string) {
    return this.ourStoryService.findAll(pairId);
  }

  @Post()
  async create(
    @Param('pairId') pairId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateSignificantDateDto,
  ) {
    return this.ourStoryService.create(pairId, user.sub, dto);
  }

  @Patch(':dateId')
  async update(
    @Param('pairId') pairId: string,
    @Param('dateId') dateId: string,
    @Body() dto: UpdateSignificantDateDto,
  ) {
    return this.ourStoryService.update(pairId, dateId, dto);
  }

  @Delete(':dateId')
  async delete(
    @Param('pairId') pairId: string,
    @Param('dateId') dateId: string,
  ) {
    return this.ourStoryService.delete(pairId, dateId);
  }
}
