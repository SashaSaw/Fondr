import { Injectable } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { ListsService } from '../lists/lists.service';

@Injectable()
export class PairActivatedListener {
  constructor(private readonly listsService: ListsService) {}

  @OnEvent('pair.activated')
  async handlePairActivated(payload: { pair: { id: string; userAId: string } }) {
    await this.listsService.seedDefaultLists(payload.pair.id, payload.pair.userAId);
  }
}
