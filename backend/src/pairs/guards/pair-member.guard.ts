import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../../common/decorators/current-user.decorator';

@Injectable()
export class PairMemberGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user as JwtPayload;
    const pairId = request.params.pairId;

    if (!pairId) {
      throw new NotFoundException('Pair ID required');
    }

    const pair = await this.prisma.pair.findUnique({
      where: { id: pairId },
    });

    if (!pair) {
      throw new NotFoundException('Pair not found');
    }

    if (pair.userAId !== user.sub && pair.userBId !== user.sub) {
      throw new ForbiddenException('Not a member of this pair');
    }

    request.pair = pair;
    return true;
  }
}
