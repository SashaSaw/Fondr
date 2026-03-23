import { Module } from '@nestjs/common';
import { PairsController } from './pairs.controller';
import { PairsService } from './pairs.service';
import { ListsModule } from '../lists/lists.module';
import { PairActivatedListener } from './pair-activated.listener';

@Module({
  imports: [ListsModule],
  controllers: [PairsController],
  providers: [PairsService, PairActivatedListener],
  exports: [PairsService],
})
export class PairsModule {}
