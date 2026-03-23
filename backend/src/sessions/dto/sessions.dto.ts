import { IsArray, IsIn, IsNotEmpty, IsString } from 'class-validator';

export class StartSessionDto {
  @IsString()
  @IsNotEmpty()
  listId: string;
}

export class SwipeDto {
  @IsString()
  @IsNotEmpty()
  itemId: string;

  @IsString()
  @IsIn(['left', 'right'])
  direction: string;
}

export class ChooseMatchDto {
  @IsString()
  @IsNotEmpty()
  chosenItemId: string;

  @IsArray()
  @IsString({ each: true })
  allMatchIds: string[];
}
