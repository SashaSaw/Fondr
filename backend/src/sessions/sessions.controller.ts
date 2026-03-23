import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Query,
  Body,
  UseGuards,
} from '@nestjs/common';
import { SessionsService } from './sessions.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PairMemberGuard } from '../pairs/guards/pair-member.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { StartSessionDto, SwipeDto, ChooseMatchDto } from './dto/sessions.dto';

@Controller('pairs/:pairId/sessions')
@UseGuards(JwtAuthGuard, PairMemberGuard)
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Get('active')
  async getActive(@Param('pairId') pairId: string) {
    return this.sessionsService.getActive(pairId);
  }

  @Get('history')
  async getHistory(
    @Param('pairId') pairId: string,
    @Query('limit') limit?: string,
  ) {
    return this.sessionsService.getHistory(pairId, limit ? parseInt(limit) : 10);
  }

  @Post()
  async start(
    @Param('pairId') pairId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: StartSessionDto,
  ) {
    return this.sessionsService.start(pairId, user.sub, dto);
  }

  @Post(':sessionId/swipe')
  async swipe(
    @Param('pairId') pairId: string,
    @Param('sessionId') sessionId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: SwipeDto,
  ) {
    return this.sessionsService.swipe(pairId, sessionId, user.sub, dto);
  }

  @Post(':sessionId/choose')
  async choose(
    @Param('pairId') pairId: string,
    @Param('sessionId') sessionId: string,
    @Body() dto: ChooseMatchDto,
  ) {
    return this.sessionsService.choose(pairId, sessionId, dto);
  }

  @Delete(':sessionId')
  async discard(
    @Param('pairId') pairId: string,
    @Param('sessionId') sessionId: string,
  ) {
    return this.sessionsService.discard(pairId, sessionId);
  }
}
