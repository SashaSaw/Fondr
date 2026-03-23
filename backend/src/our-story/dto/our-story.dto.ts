import { IsBoolean, IsDateString, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateSignificantDateDto {
  @IsString()
  @IsNotEmpty()
  title: string;

  @IsDateString()
  date: string; // yyyy-MM-dd

  @IsString()
  @IsOptional()
  emoji?: string;

  @IsBoolean()
  recurring: boolean;
}

export class UpdateSignificantDateDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsDateString()
  @IsOptional()
  date?: string;

  @IsString()
  @IsOptional()
  emoji?: string;

  @IsBoolean()
  @IsOptional()
  recurring?: boolean;
}
