import * as z from 'zod';
import { MediaType } from '@prisma/client';


const MAX_BATCH_SIZE = 10;
const IMAGE_MIME_TYPES = ['image/jpeg', 'image/png','image/jpg', 'image/webp'];
const MAX_FILE_SIZE = 1000 * 1024 * 1024; // 1GB
const ALLOWED_MIME_TYPES = [
    'video/mp4', 'video/quicktime', 'video/x-msvideo',
    'audio/mpeg', 'audio/wav', 'audio/ogg',
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg', 'image/png', 'image/webp'
];

export const createMediaAssetSchema = z.object({
        fileName: z.string(),
        fileSize: z.number().int(),
        mimeType: z.string(),
        mediaPath: z.string(),
        type: z.enum(MediaType),
        duration: z.number().int().optional()
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

