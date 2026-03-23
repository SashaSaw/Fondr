import { IsBoolean, IsNotEmpty, IsOptional, IsString } from 'class-validator';

// --- Availability ---

export class CreateAvailabilityDto {
  @IsString()
  @IsNotEmpty()
  date: string; // yyyy-MM-dd

  @IsString()
  @IsOptional()
  startTime?: string; // HH:mm UTC

  @IsString()
  @IsOptional()
  endTime?: string; // HH:mm UTC

  @IsString()
  @IsOptional()
  label?: string;
}

export class UpdateAvailabilityDto {
  @IsString()
  @IsOptional()
  startTime?: string;

  @IsString()
  @IsOptional()
  endTime?: string;

  @IsString()
  @IsOptional()
  label?: string;
}

// --- Events ---

export class CreateEventDto {
  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsNotEmpty()
  startDate: string; // yyyy-MM-dd

  @IsString()
  @IsNotEmpty()
  endDate: string;

  @IsString()
  @IsOptional()
  startTime?: string;

  @IsString()
  @IsOptional()
  endTime?: string;
}

export class UpdateEventDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsOptional()
  startDate?: string;

  @IsString()
  @IsOptional()
  endDate?: string;

  @IsString()
  @IsOptional()
  startTime?: string;

  @IsString()
  @IsOptional()
  endTime?: string;
}

export class RespondEventDto {
  @IsBoolean()
  accepted: boolean;

  @IsString()
  @IsOptional()
  reason?: string;
}
