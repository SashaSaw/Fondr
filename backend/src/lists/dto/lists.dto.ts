import {
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateListDto {
  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsNotEmpty()
  emoji: string;

  @IsString()
  @IsOptional()
  subtitle?: string;
}

export class UpdateListDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  emoji?: string;

  @IsString()
  @IsOptional()
  subtitle?: string;

  @IsInt()
  @IsOptional()
  sortOrder?: number;
}

export class CreateItemDto {
  @IsString()
  @IsNotEmpty()
  listId: string;

  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsOptional()
  imageUrl?: string;

  // TMDB metadata
  @IsInt()
  @IsOptional()
  metadataTmdbId?: number;

  @IsString()
  @IsOptional()
  metadataYear?: string;

  @IsString()
  @IsOptional()
  metadataGenre?: string;

  @IsNumber()
  @IsOptional()
  metadataRating?: number;

  @IsString()
  @IsOptional()
  metadataRuntime?: string;
}

export class UpdateItemDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsOptional()
  status?: string;

  @IsString()
  @IsOptional()
  completionNote?: string;
}
