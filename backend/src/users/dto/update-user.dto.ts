import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class UpdateUserDto {
  @IsString()
  @IsOptional()
  displayName?: string;

  @IsString()
  @IsOptional()
  timezone?: string;

  @IsString()
  @IsOptional()
  partnerName?: string;

  @IsBoolean()
  @IsOptional()
  onboardingCompleted?: boolean;
}

export class UpdateApnsTokenDto {
  @IsString()
  token: string;
}
