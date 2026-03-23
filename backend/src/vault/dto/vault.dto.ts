import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateVaultFactDto {
  @IsString()
  @IsIn(['basics', 'food', 'gifts', 'notes'])
  category: string;

  @IsString()
  @IsNotEmpty()
  label: string;

  @IsString()
  @IsNotEmpty()
  value: string;
}

export class UpdateVaultFactDto {
  @IsString()
  @IsOptional()
  label?: string;

  @IsString()
  @IsOptional()
  value?: string;
}
