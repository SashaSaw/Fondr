import { Injectable, Logger, OnModuleInit } from '@nestjs/common';

// apns2 types
let ApnsClient: any;
let Notification: any;

@Injectable()
export class ApnsService implements OnModuleInit {
  private client: any;
  private readonly logger = new Logger(ApnsService.name);

  async onModuleInit() {
    try {
      const apns2 = await import('apns2');
      ApnsClient = apns2.ApnsClient;
      Notification = apns2.Notification;
    } catch {
      this.logger.warn('apns2 module not available — push notifications disabled');
      return;
    }

    const keyId = process.env.APNS_KEY_ID;
    const teamId = process.env.APNS_TEAM_ID;
    const rawKey = process.env.APNS_PRIVATE_KEY;

    // Decode base64-encoded key if needed
    let signingKey = rawKey;
    if (rawKey && !rawKey.includes('BEGIN PRIVATE KEY')) {
      signingKey = Buffer.from(rawKey, 'base64').toString('utf-8');
    }

    if (!keyId || !teamId || !signingKey) {
      this.logger.warn('APNs credentials not configured — push notifications disabled');
      return;
    }

    this.client = new ApnsClient({
      team: teamId,
      keyId,
      signingKey,
      defaultTopic: process.env.APNS_BUNDLE_ID || 'com.fondr.app',
      host: process.env.APNS_PRODUCTION === 'true'
        ? 'api.push.apple.com'
        : 'api.sandbox.push.apple.com',
    });

    this.logger.log('APNs client initialized');
  }

  async send(
    deviceToken: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    if (!this.client || !Notification) {
      this.logger.debug(`APNs not configured, skipping: "${title}" -> ${deviceToken.substring(0, 8)}...`);
      return;
    }

    try {
      const notification = new Notification(deviceToken, {
        alert: { title, body },
        sound: 'default',
        badge: 1,
        data,
      });

      await this.client.send(notification);
    } catch (err: any) {
      this.logger.error(`APNs send error: ${err.message}`, err.stack);
    }
  }
}
