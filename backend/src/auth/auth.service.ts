import {
  Injectable,
  UnauthorizedException,
  ConflictException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import appleSignin from 'apple-signin-auth';
import { PrismaService } from '../prisma/prisma.service';
import { AppleSignInDto, RegisterDto, LoginDto, AuthResponse } from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async appleSignIn(dto: AppleSignInDto): Promise<AuthResponse> {
    const applePayload = await appleSignin.verifyIdToken(dto.identityToken, {
      audience: process.env.APPLE_CLIENT_ID,
      ignoreExpiration: false,
    });

    const appleSub = applePayload.sub;
    const email = applePayload.email || null;

    let user = await this.prisma.user.findUnique({
      where: { appleSub },
    });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          appleSub,
          email,
          displayName: dto.fullName || email || 'User',
        },
      });
    }

    return this.generateTokens(user);
  }

  async register(dto: RegisterDto): Promise<AuthResponse> {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        displayName: dto.displayName,
      },
    });

    return this.generateTokens(user);
  }

  async login(dto: LoginDto): Promise<AuthResponse> {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return this.generateTokens(user);
  }

  async refresh(refreshToken: string): Promise<AuthResponse> {
    const user = await this.prisma.user.findFirst({
      where: { refreshToken },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    return this.generateTokens(user);
  }

  private async generateTokens(user: {
    id: string;
    email: string | null;
    displayName: string;
    profileImageUrl: string | null;
    pairId: string | null;
    onboardingCompleted: boolean;
  }): Promise<AuthResponse> {
    const payload = { sub: user.id, email: user.email };

    const accessToken = this.jwtService.sign(payload);
    const refreshToken = uuidv4();

    await this.prisma.user.update({
      where: { id: user.id },
      data: { refreshToken },
    });

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        profileImageUrl: user.profileImageUrl,
        pairId: user.pairId,
        onboardingCompleted: user.onboardingCompleted,
      },
    };
  }
}
