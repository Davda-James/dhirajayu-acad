import { Request, Response } from 'express';
import prisma from '@/shared/db';
import * as z from 'zod';
import { MediaType } from '@prisma/client';
import ENV from '@/shared/config/env';
import { signWithJWT } from '@v0/utils/mediaSigner';

// Create a new media asset (upload file to library)
export async function createMediaAsset(req: Request, res: Response) {
    const schema = z.object({
        fileName: z.string(),
        fileSize: z.number().int(),
        mimeType: z.string(),
        mediaPath: z.string(),
        type: z.enum(MediaType),
        duration: z.number().int().optional()
    }).strict();
    try {
        const parsed = schema.safeParse(req.body);
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid input', errors: parsed.error.issues });
        }
        const { fileName, fileSize, mimeType, mediaPath, type, duration } = parsed.data;
        const asset = await prisma.mediaAsset.create({
            data: {
                file_name: fileName,
                file_size: BigInt(fileSize),
                mime_type: mimeType,
                media_path: mediaPath,
                type,
                duration: duration ?? null
            }
        });
        return res.status(201).json({ message: 'Media asset created', asset });
    } catch (error) {
        return res.status(500).json({ message: 'Error creating media asset' });
    }
}

// List all media assets (library)w
export async function listMediaAssets(req: Request, res: Response) {
    try {
        const assets = await prisma.mediaAsset.findMany({ orderBy: { created_at: 'desc' } });
        return res.status(200).json({ assets });
    } catch (error) {
        return res.status(500).json({ message: 'Error fetching media assets' });
    }
}

export async function getMediaAccessToken(req: Request, res: Response) {
    const schema = z.object({
        assetId: z.cuid()
    }).strict(); 
    try {
        const parsed = schema.safeParse(req.params);
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid asset ID', errors: parsed.error.issues });
        }
        const { assetId } = parsed.data;
        const asset = await prisma.mediaAsset.findUnique({ where: { id: assetId } });
        if (!asset) {
            return res.status(404).json({ message: 'Media asset not found' });
        }
        const userId = req.user.firebase_id;
        const token = await signWithJWT(userId);

        return res.status(200).json({
            media_url: `${ENV.WORKER_BASE_URL}/${asset.media_path}`,
            worker_token: token,
            expires_in: 3600
        });
    } catch (error) {
        return res.status(500).json({ message: 'Error generating access token' });
    }
}