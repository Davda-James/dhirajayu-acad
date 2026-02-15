import { Request, Response } from 'express';
import prisma from '@/shared/db';
import { createGalleryMediaAssetSchema, mediaAccessTokenSchema, mediaAccessTokenSchemaQuery, listGalleryMediaSchema, deleteGalleryMediaAssetSchema, imageUploadSchema, externalVideoUploadSchema } from '@/shared/schema/media';
import ENV from '@/shared/config/env';
import { signWithJWT } from '@v0/utils/mediaSigner';
import mime from 'mime-types';
import { MediaStatus, MediaType } from '@prisma/client';
import { cloudflareR2 } from '../services/objectStore';

/* 
    createGalleryMediaAsset and requestGalleryMediaUpload are for gallery use only
    for courses it is automatically handled in courses and mediaUsages controller
*/
export async function createGalleryMediaImage(req: Request, res: Response) {
    try {
        const parsed = createGalleryMediaAssetSchema.safeParse(req.body);
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid input', errors: parsed.error.issues });
        }
        const { fileName, fileSize, mimeType, mediaPath,  type } = parsed.data;
        const fileExists = await cloudflareR2.checkFileExists(mediaPath);
        if (!fileExists) {
            return res.status(400).json({ message: 'File does not exist in storage' });
        }
        const asset = await prisma.mediaAsset.create({
            data: {
                file_name: fileName,
                file_size: BigInt(fileSize),
                mime_type: mimeType,
                media_path: mediaPath,
                is_for_gallery: true,
                status: MediaStatus.ACTIVE,
                type,
            },
            select: {
                id: true,
                file_name: true,
                media_path: true,
                mime_type: true,
                type: true,
            }
        });
        
        return res.status(201).json({ message: 'Media asset created', asset });
    } catch (error) {
        console.error('Error creating media asset:', error);
        return res.status(500).json({ message: 'Error creating media asset' });
    }
}

export async function requestGalleryImageUpload(req: Request, res: Response) {
    try {
        const parsed = imageUploadSchema.safeParse(req.body);
        if (!parsed.success) {
            console.log('Validation errors:', parsed.error.issues);
            return res.status(400).json({ message: 'Invalid input', errors: parsed.error.issues });
        }
        const { media } = parsed.data;
        const galleryId = crypto.randomUUID();
        const fileExtension = mime.extension(media.mimeType);
        if (!fileExtension) throw new Error("Unsupported MIME type");
        const fileKey = `gallery/${galleryId}.${fileExtension}`;
        const uploadUrl = await cloudflareR2.getPreSignedUploadUrl(fileKey);
        return res.status(200).json({ uploadUrl, fileKey });        

    } catch (error) {
        console.log('Error requesting gallery image upload:', error);
        return res.status(500).json({ message: 'Error creating media asset' });
    }
} 

export async function createGalleryMediaVideo(req: Request, res: Response) {
    try {
        const parsed = externalVideoUploadSchema.safeParse(req.body);
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid input', errors: parsed.error.issues });
        }
        const { url } = parsed.data;
        const video = await prisma.galleryVideos.create({ data: { url } });

        return res.status(201).json({ message: 'Gallery video created', video });
    } catch (error) {
        console.log('Error requesting gallery video upload:', error);
        return res.status(500).json({ message: 'Error creating media asset' });
    }
}

export async function deleteGalleryMediaAsset(req: Request, res: Response) {
    try {
        const parsed = deleteGalleryMediaAssetSchema.safeParse(req.params);
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid input', errors: parsed.error.issues });
        }
        const { assetId, type } = parsed.data;
        if (type === 'VIDEO') {
            await prisma.galleryVideos.delete({ where: { id: assetId } });
            return res.status(200).json({ message: 'Gallery video deleted' });
        }
        const asset = await prisma.mediaAsset.findUnique({ where: { id: assetId } });
        if (!asset) {
            return res.status(404).json({ message: 'Media asset not found' });
        }
        if (!asset.is_for_gallery) {
            return res.status(400).json({ message: 'Only gallery media assets can be deleted through this endpoint' });
        }
        await cloudflareR2.deleteMediaFile(asset.media_path);
        await prisma.mediaAsset.delete({ where: { id: assetId } });
        return res.status(200).json({ message: 'Media asset deleted' });
    } catch (error) {
        console.log('Error deleting gallery media asset:', error);
        return res.status(500).json({ message: 'Error deleting media asset' });
    }
}

export async function getMediaAccessToken(req: Request, res: Response) {
    try {
        const parsed = mediaAccessTokenSchema.safeParse(req.params);
        const parsedQuery = mediaAccessTokenSchemaQuery.safeParse(req.query);
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid asset ID', errors: parsed.error.issues });
        }
        if (!parsedQuery.success) {
            return res.status(400).json({ message: 'Invalid query parameters', errors: parsedQuery.error.issues });
        }
        const { assetId } = parsed.data;
        const { courseId } = parsedQuery.data;
        const asset = await prisma.mediaAsset.findUnique({ where: { id: assetId } });
        if (!asset) {
            return res.status(404).json({ message: 'Media asset not found' });
        }
        if(!asset.is_free_preview && req.user.role !== 'ADMIN' && !courseId) {
            return res.status(400).json({ message: 'Course ID is required for non-free media assets' });
        }
        if (courseId) {
            const course = await prisma.courses.findUnique({
                where: { id: courseId },
                select: { id: true }
            });
            if (!course) {
                return res.status(404).json({ message: 'Course not found' });
            }
        }
        const userId = req.user.firebase_id;
        const token = await signWithJWT(userId, ENV.MEDIA_WORKER_TOKEN_TTL_SECONDS);
        return res.status(200).json({
            media_url: `${ENV.WORKER_BASE_URL}/${asset.media_path}`,
            worker_token: token,
            expires_in: ENV.MEDIA_WORKER_TOKEN_TTL_SECONDS
        });
    } catch (error) {
        return res.status(500).json({ message: 'Error generating access token' });
    }
}

// fetch media for gallery 
export async function listGalleryMedia(req: Request, res: Response) {
    try {
        const parsed = listGalleryMediaSchema.safeParse(req.query);  
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid input', errors: parsed.error.issues });
        }
        const { type } = parsed.data;
        if (type === 'IMAGE') {
            const assets = await prisma.mediaAsset.findMany({
                where: { is_for_gallery: true, type, status: 'ACTIVE' },
                select: {
                    id: true,
                    media_path: true,
                },
                orderBy: { created_at: 'desc' }
            });
            const formattedAssets = assets.map(image => ({
                id: image.id,
                url: `${ENV.WORKER_BASE_URL}/${image.media_path}`
            }));
            return res.status(200).json({ assets: formattedAssets });
        } 
        const assets = await prisma.galleryVideos.findMany({
            select: {
                id: true,
                url: true,
            },
            orderBy: { created_at: 'desc' }
        });
        return res.status(200).json({ assets });
    } catch (error) {
        console.log(error);
        return res.status(500).json({ message: 'Error fetching gallery images' });
    }
}
