import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Query,
  Body,
  UseGuards,
} from '@nestjs/common';
import { ListsService } from './lists.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PairMemberGuard } from '../pairs/guards/pair-member.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { CreateListDto, UpdateListDto, CreateItemDto, UpdateItemDto } from './dto/lists.dto';

@Controller('pairs/:pairId')
@UseGuards(JwtAuthGuard, PairMemberGuard)
export class ListsController {
  constructor(private readonly listsService: ListsService) {}

  // --- Lists ---

  @Get('lists')
  async findAllLists(@Param('pairId') pairId: string) {
    return this.listsService.findAllLists(pairId);
  }

  @Post('lists')
  async createList(
    @Param('pairId') pairId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateListDto,
  ) {
    return this.listsService.createList(pairId, user.sub, dto);
  }

  @Patch('lists/:listId')
  async updateList(
    @Param('pairId') pairId: string,
    @Param('listId') listId: string,
    @Body() dto: UpdateListDto,
  ) {
    return this.listsService.updateList(pairId, listId, dto);
  }

  @Delete('lists/:listId')
  async deleteList(
    @Param('pairId') pairId: string,
    @Param('listId') listId: string,
  ) {
    return this.listsService.deleteList(pairId, listId);
  }

  // --- Items ---

  @Get('items')
  async findAllItems(
    @Param('pairId') pairId: string,
    @Query('listId') listId?: string,
  ) {
    return this.listsService.findAllItems(pairId, listId);
  }

  @Post('items')
  async createItem(
    @Param('pairId') pairId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateItemDto,
  ) {
    return this.listsService.createItem(pairId, user.sub, dto);
  }

  @Patch('items/:itemId')
  async updateItem(
    @Param('pairId') pairId: string,
    @Param('itemId') itemId: string,
    @Body() dto: UpdateItemDto,
  ) {
    return this.listsService.updateItem(pairId, itemId, dto);
  }

  @Delete('items/:itemId')
  async deleteItem(
    @Param('pairId') pairId: string,
    @Param('itemId') itemId: string,
  ) {
    return this.listsService.deleteItem(pairId, itemId);
  }
}
