import { SignJWT } from 'jose';
import ENV from '@/shared/config/env';

export async function signWithJWT(userId: string, ttlSeconds: number = 3600): Promise<string> {
    try {
        const workerTokenTtl = 60 * 60; 
        const now = Math.floor(Date.now() / 1000);
        const secret = new TextEncoder().encode(ENV.JWT_SECRET);
        const token = await new SignJWT({ userId })
            .setProtectedHeader({ alg: 'HS256' })
            .setIssuedAt(now)
            .setExpirationTime(now + workerTokenTtl)
            .sign(secret);

        return token;
    } catch (error) {
        throw new Error(`Error signing JWT: ${error}`);
    }
}
