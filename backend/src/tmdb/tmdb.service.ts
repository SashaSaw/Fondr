import { Injectable, BadRequestException } from '@nestjs/common';

const TMDB_BASE_URL = 'https://api.themoviedb.org/3';
const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p/w500';

@Injectable()
export class TmdbService {
  private get apiKey(): string {
    return process.env.TMDB_API_KEY || '';
  }

  async search(query: string) {
    if (!query || query.trim().length === 0) {
      throw new BadRequestException('Query is required');
    }

    if (!this.apiKey) {
      return { results: [] };
    }

    const url = `${TMDB_BASE_URL}/search/movie?api_key=${this.apiKey}&query=${encodeURIComponent(query)}&page=1`;
    const response = await fetch(url);

    if (!response.ok) {
      return { results: [] };
    }

    const data = await response.json();

    // Map to simplified format matching iOS MovieMetadata
    const results = (data.results || []).slice(0, 20).map((movie: any) => ({
      tmdbId: movie.id,
      title: movie.title,
      year: movie.release_date?.substring(0, 4) || null,
      overview: movie.overview,
      posterUrl: movie.poster_path
        ? `${TMDB_IMAGE_BASE}${movie.poster_path}`
        : null,
      rating: movie.vote_average,
      genreIds: movie.genre_ids,
    }));

    return { results };
  }
}
