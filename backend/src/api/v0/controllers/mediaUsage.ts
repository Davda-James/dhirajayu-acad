import { Request, Response } from 'express';
import prisma from '@/shared/db';
import * as z from 'zod';
import { cloudflareR2 } from '@/api/v0/services/objectStore';
import { createMediaUsageSchema, deleteMediaUsageSchema, listMediaUsagesByFolderSchema, updateMediaUsageSchema } from '@/shared/schema/media';

// Create a new media usage (place asset in course/module/folder)
export async function createMediaUsage(req: Request, res: Response) {    
    try {
        const parsed = createMediaUsageSchema.safeParse(req.body);
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid input', errors: parsed.error.issues });
        }
        const { mediaId, courseId, moduleId, moduleFolderId, title, description, isFreePreview, order } = parsed.data;
        
        // Auto-assign order if not provided: get max order in folder and increment
        let finalOrder = order;
        if (!finalOrder) {
            const maxOrderUsage = await prisma.mediaUsage.findFirst({
                where: { module_folder_id: moduleFolderId },
                orderBy: { order: 'desc' },
                select: { order: true }
            });
            finalOrder = maxOrderUsage ? maxOrderUsage.order + 1 : 0;
        }

        const usage = await prisma.mediaUsage.create({
            data: {
                media_id: mediaId,
                course_id: courseId,
                module_id: moduleId,
                module_folder_id: moduleFolderId,
                title,
                description: description ?? null,
                order: finalOrder
            }
        });
        return res.status(201).json({ message: 'Media usage created', usage });
    } catch (error) {
        return res.status(500).json({ message: 'Error creating media usage' });
    }
}

// List usages for a folder
export async function listMediaUsagesByFolder(req: Request, res: Response) {
    try {
        const parsed = listMediaUsagesByFolderSchema.safeParse(req.params);
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid folder ID', errors: parsed.error.issues });
        }
        const { folderId } = parsed.data;
        if (req.user.role !== 'ADMIN') {
            // Verify that the user is enrolled in the course containing this folder
            const folder = await prisma.moduleFolder.findUnique({
                where: { id: folderId },
                include: { module: { select: { course: { select: { id: true, is_paid: true }}}}},
            });
            
            if (!folder) {
                return res.status(404).json({ message: 'Folder not found' });
            }

            const course = folder.module.course;
            if (course.is_paid) {
                const isEnrolled = await prisma.enrollments.findFirst({
                    where: {
                        user_id: req.user.uid!, // Assuming `req.user.id` contains the authenticated user's ID
                        course_id: course.id,
                    },
                });
                if(!isEnrolled) {
                    return res.status(403).json({ message: 'Access denied to this folder' });
                }
            }
        }

        const usages = await prisma.mediaUsage.findMany({
            where: { module_folder_id: folderId },
            include: { media_asset: true },
            orderBy: { order: 'asc' }
        });

        // Compute simple ETag based on latest updated_at among usages
        let latest = new Date(0);
        for (const u of usages) {
            if (u.updated_at && u.updated_at > latest) latest = u.updated_at;
        }
        const etag = `"${latest.getTime()}"`;
        const ifNoneMatch = req.headers['if-none-match'];
        if (ifNoneMatch && ifNoneMatch === etag) {
            return res.status(304).end();
        }

        // Convert BigInt values to strings to avoid JSON serialization issues
        const sanitizedUsages = usages.map((usage) => ({
            ...usage,
            media_asset: {
                ...usage.media_asset,
                file_size: usage.media_asset?.file_size?.toString() ?? null,
            },
        }));

        res.setHeader('ETag', etag);
        return res.status(200).json({ usages: sanitizedUsages });
    } catch (error) {
        return res.status(500).json({ message: 'Error fetching media usages' });
    }
}

// Update a media usage (placement)
export async function updateMediaUsage(req: Request, res: Response) {
    try {
        const parsed = updateMediaUsageSchema.safeParse(req.body);
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid input', errors: parsed.error.issues });
        }
        const { usageId, title, description, isFreePreview, order } = parsed.data;
        const updateData: any = {};
        if (title !== undefined) updateData.title = title;
        if (description !== undefined) updateData.description = description;
        if (isFreePreview !== undefined) updateData.is_free_preview = isFreePreview;
        if (order !== undefined) updateData.order = order;
        if (Object.keys(updateData).length === 0) {
            return res.status(400).json({ message: 'No fields to update' });
        }
        const usage = await prisma.mediaUsage.update({
            where: { id: usageId },
            data: updateData
        });
        return res.status(200).json({ message: 'Media usage updated', usage });
    } catch (error: any) {
        if (error.code === 'P2025') {
            return res.status(404).json({ message: 'Media usage not found' });
        }
        return res.status(500).json({ message: 'Error updating media usage' });
    }
}

// Delete a media usage (placement) and clean up orphaned asset if needed
export async function deleteMediaUsage(req: Request, res: Response) {
    try {
        const parsed = deleteMediaUsageSchema.safeParse(req.params);
        if (!parsed.success) {
            return res.status(400).json({ message: 'Invalid input', errors: parsed.error.issues });
        }
        const { usageId } = parsed.data;
        const usage = await prisma.mediaUsage.findUnique({
            where: { id: usageId },
            include: { media_asset: true }
        });

        if (!usage) {
            return res.status(404).json({ message: 'Media usage not found' });
        }
        const assetId = usage.media_id;
        const asset = usage.media_asset;
        if (!asset) {
            // Asset missing but usage exists: delete usage only
            await prisma.mediaUsage.delete({ where: { id: usageId } });
            return res.status(200).json({ message: 'Media usage deleted (no asset attached)' });
        }
        // Delete the MediaUsage (placement)
        await prisma.mediaUsage.delete({ where: { id: usageId } });
        // Check if any usages remain for this asset
        const remainingUsages = await prisma.mediaUsage.count({ where: { media_id: assetId } });
        if (remainingUsages === 0) {
            // Delete from object store
            try {
                await cloudflareR2.deleteMediaFile(asset.media_path);
            } catch (b2Error) {
                console.error('B2 deletion error:', b2Error);
            }
            // Delete the MediaAsset
            await prisma.mediaAsset.delete({ where: { id: assetId } });
            return res.status(200).json({ message: 'Media usage and asset deleted successfully' });
        }
        return res.status(200).json({ message: 'Media usage deleted. Asset retained (still in use elsewhere)' });
    } catch (error) {
        return res.status(500).json({ message: 'Error deleting media usage' });
    }
}


