import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as crypto from 'crypto';

@Injectable()
export class StorageService {
  constructor(private readonly prisma: PrismaService) {}

  async uploadProfileImage(userId: string, file: Express.Multer.File): Promise<string> {
    // For Eve object store, we'll store the file and return a URL.
    // In production with Eve's object store, this would use S3-compatible SDK.
    // For now, we store the image as a base64 data URL or use the object store env vars.

    const bucket = process.env.STORAGE_BUCKET_UPLOADS;
    const endpoint = process.env.STORAGE_ENDPOINT;
    const accessKey = process.env.STORAGE_ACCESS_KEY_ID;
    const secretKey = process.env.STORAGE_SECRET_ACCESS_KEY;
    const region = process.env.STORAGE_REGION || 'us-east-1';

    if (endpoint && accessKey && secretKey && bucket) {
      // Use S3-compatible upload (Eve object store / MinIO)
      const { S3Client, PutObjectCommand, GetObjectCommand } = await import('@aws-sdk/client-s3');

      const s3 = new S3Client({
        endpoint,
        region,
        credentials: {
          accessKeyId: accessKey,
          secretAccessKey: secretKey,
        },
        forcePathStyle: process.env.STORAGE_FORCE_PATH_STYLE === 'true',
      });

      const key = `users/${userId}/profile.jpg`;

      await s3.send(
        new PutObjectCommand({
          Bucket: bucket,
          Key: key,
          Body: file.buffer,
          ContentType: 'image/jpeg',
        }),
      );

      const url = `${endpoint}/${bucket}/${key}`;

      await this.prisma.user.update({
        where: { id: userId },
        data: { profileImageUrl: url },
      });

      return url;
    }

    // Fallback: store locally (dev mode)
    const hash = crypto.createHash('md5').update(file.buffer).digest('hex');
    const url = `/uploads/${userId}_${hash}.jpg`;

    await this.prisma.user.update({
      where: { id: userId },
      data: { profileImageUrl: url },
    });

    return url;
  }
}
