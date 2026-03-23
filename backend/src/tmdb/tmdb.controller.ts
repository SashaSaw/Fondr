import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TmdbService } from './tmdb.service';

@Controller('tmdb')
@UseGuards(JwtAuthGuard)
export class TmdbController {
  constructor(private readonly tmdbService: TmdbService) {}

  @Get('search')
  async search(@Query('query') query: string) {
    return this.tmdbService.search(query);
  }
}
