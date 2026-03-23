import { IsDateString, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class JoinPairDto {
  @IsString()
  @IsNotEmpty()
  inviteCode: string;
}

export class UpdatePairDto {
  @IsDateString()
  @IsOptional()
  anniversary?: string;
}
