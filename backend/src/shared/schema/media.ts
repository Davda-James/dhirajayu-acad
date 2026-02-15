import * as z from 'zod';
import { MediaType } from '@prisma/client';


const MAX_BATCH_SIZE = 10;
const IMAGE_MIME_TYPES = ['image/jpeg', 'image/png','image/jpg', 'image/webp'];
const MAX_FILE_SIZE = 2000 * 1024 * 1024; // 2GB
const ALLOWED_MIME_TYPES = [
    'video/mp4', 'video/quicktime', 'video/x-msvideo',
    'audio/mpeg', 'audio/wav', 'audio/ogg',
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg', 'image/png', 'image/webp'
];

export const createGalleryMediaAssetSchema = z.object({
    fileName: z.string(),
    fileSize: z.number().int(),
    mimeType: z.string(),
    mediaPath: z.string(),
    type: z.enum(MediaType),
}).strict();

export const imageUploadSchema = z.object({
    media: z.object({
        fileName: z.string(),
        fileSize: z.number().max(MAX_FILE_SIZE),
        mimeType: z.string().refine(val => IMAGE_MIME_TYPES.includes(val)),
    })
}).strict();

export const courseMediaUpload = z.object({
    courseId: z.cuid(),
    moduleId: z.cuid(),
    moduleFolderId: z.cuid(),
    media: z.array(z.object({
        fileName: z.string(),
        fileSize: z.number().max(MAX_FILE_SIZE),
        mimeType: z.string().refine(val => ALLOWED_MIME_TYPES.includes(val)),
        type: z.enum(MediaType),
        title: z.string().min(1),
        description: z.string().optional(),
        duration: z.number().nullable().optional()
    })).max(MAX_BATCH_SIZE)
}).strict();

export const mediaAccessTokenSchema = z.object({
    assetId: z.cuid(),
}).strict();

export const mediaAccessTokenSchemaQuery = z.object({
    courseId: z.cuid().optional()
}).strict();

export const createMediaUsageSchema = z.object({
    mediaId: z.cuid(),
    courseId: z.cuid(),
    moduleId: z.cuid(),
    moduleFolderId: z.cuid(),
    title: z.string().min(1),
    description: z.string().optional(),
    isFreePreview: z.boolean().optional(),
    order: z.number().int().optional()
}).strict();

export const listMediaUsagesByFolderSchema = z.object({
    folderId: z.cuid()
}).strict();

export const updateMediaUsageSchema = z.object({
    usageId: z.cuid(),
    title: z.string().min(1).optional(),
    description: z.string().optional(),
    isFreePreview: z.boolean().optional(),
    order: z.number().int().optional()
}).strict();

export const deleteMediaUsageSchema = z.object({
    usageId: z.cuid()
}).strict();

export const confirmMediaUploadSchema = z.object({
    mediaIds: z.array(z.cuid()).min(1).max(MAX_BATCH_SIZE)
}).strict();

export const listGalleryMediaSchema = z.object({
    type: z.enum(MediaType),    
}).strict();

export const deleteGalleryMediaAssetSchema = z.object({
    assetId: z.cuid(),
    type: z.enum(MediaType)
}).strict();

export const externalVideoUploadSchema = z.object({
    url: z.url(),
}).strict();