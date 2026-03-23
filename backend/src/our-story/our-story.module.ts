import { Module } from '@nestjs/common';
import { OurStoryController } from './our-story.controller';
import { OurStoryService } from './our-story.service';

@Module({
  controllers: [OurStoryController],
  providers: [OurStoryService],
})
export class OurStoryModule {}
