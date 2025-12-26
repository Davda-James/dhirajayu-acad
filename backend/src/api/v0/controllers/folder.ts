import { Request, Response } from 'express';
import prisma from '@/shared/db';
import * as z from 'zod';
import { cloudflareR2 } from '@v0/services/objectStore';

export async function createFolder(req: Request, res: Response) {
    const schema = z.object({
        moduleId: z.cuid(),
        title: z.string().min(1),
        description: z.string().optional(),
        parentId: z.string().cuid().nullable().optional()
    }).strict();

    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ 
                message: "Invalid input",
                errors: parsedResult.error.issues 
            });
        }

        const { moduleId, title, description, parentId } = parsedResult.data;

        const module = await prisma.modules.findUnique({
            where: { id: moduleId }
        });

        if (!module) {
            return res.status(404).json({ message: "Module not found" });
        }

        const folder = await prisma.moduleFolder.create({
            data: {
                module_id: moduleId,
                title,
                description: description || null,
                parent_id: parentId ?? null
            }
        });

        return res.status(201).json({
            message: "Folder created",
            folder: {
                id: folder.id,
                moduleId: folder.module_id,
                title: folder.title,
                description: folder.description,
                parentId: folder.parent_id
            }
        });
    } catch (error) {
        return res.status(500).json({ message: "Error creating folder" });
    }
}

// Helper: Build recursive folder tree
function buildFolderTree(
    folders: any[],
    parentId: string | null = null
): Array<{
    id: string;
    moduleId: string;
    title: string;
    description?: string | null;
    mediaCount: number;
    createdAt: Date;
    children: any[];
}> {
    return folders
        .filter((f: any) => f.parent_id === parentId)
        .map((f: any) => ({
            id: f.id,
            moduleId: f.module_id,
            title: f.title,
            description: f.description,
            mediaCount: f._count.mediaUsages,
            createdAt: f.created_at,
            children: buildFolderTree(folders, f.id)
        }));
}

// Get Folders by Module (recursive tree)
export async function getFoldersByModule(req: Request, res: Response) {
    const schema = z.object({
        moduleId: z.cuid()
    }).strict();

    try {
        const parsedResult = schema.safeParse(req.params);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid module ID" });
        }
        const { moduleId } = parsedResult.data;
        // Fetch all folders for this module, including parent_id and media usage count
        const folders = await prisma.moduleFolder.findMany({
            where: { module_id: moduleId },
            include: {
                _count: { select: { mediaUsages: true } }
            },
            orderBy: { created_at: 'asc' }
        });
        // Build recursive tree
        const tree = buildFolderTree(folders, null);
        return res.status(200).json({ folders: tree });
    } catch (error) {
        console.error('Get folders error:', error);
        return res.status(500).json({ message: "Error fetching folders" });
    }
}

// Update Folder (allow moving in tree)
export async function updateFolder(req: Request, res: Response) {
    const schema = z.object({
        folderId: z.cuid(),
        title: z.string().min(1).optional(),
        description: z.string().optional(),
        parentId: z.string().cuid().nullable().optional() // allow moving folder
    }).strict();

    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ 
                message: "Invalid input",
                errors: parsedResult.error.issues 
            });
        }
        const { folderId, title, description, parentId } = parsedResult.data;
        const updateData: any = {};
        if (title !== undefined) updateData.title = title;
        if (description !== undefined) updateData.description = description;
        if (parentId !== undefined) updateData.parent_id = parentId;
        if (Object.keys(updateData).length === 0) {
            return res.status(400).json({ message: "No fields to update" });
        }
        const folder = await prisma.moduleFolder.update({
            where: { id: folderId },
            data: updateData
        });
        return res.status(200).json({
            message: "Folder updated",
            folder: {
                id: folder.id,
                moduleId: folder.module_id,
                title: folder.title,
                description: folder.description,
                parentId: folder.parent_id
            }
        });
    } catch (error: any) {
        if (error.code === 'P2025') {
            return res.status(404).json({ message: "Folder not found" });
        }
        console.error('Update folder error:', error);
        return res.status(500).json({ message: "Error updating folder" });
    }
}

async function getAllDescendantFolderIds(folderId: string): Promise<string[]> {
    const children = await prisma.moduleFolder.findMany({ where: { parent_id: folderId } });
    let ids = children.map(f => f.id);
    for (const child of children) {
        ids = ids.concat(await getAllDescendantFolderIds(child.id));
    }
    return ids;
}

// Delete Folder (recursive, with orphaned asset cleanup)
export async function deleteFolder(req: Request, res: Response) {
    const schema = z.object({
        folderId: z.cuid()
    }).strict();
    try {
        const parsedResult = schema.safeParse(req.params);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid folder ID" });
        }
        const { folderId } = parsedResult.data;
        // Find all descendant folders
        const descendantIds = await getAllDescendantFolderIds(folderId);
        const allIds = [folderId, ...descendantIds];
        // Find all media usages in these folders (before deletion)
        const usages = await prisma.mediaUsage.findMany({ where: { module_folder_id: { in: allIds } } });
        const assetIds = usages.map(u => u.media_id);
        // Delete all media usages in these folders
        await prisma.mediaUsage.deleteMany({ where: { module_folder_id: { in: allIds } } });
        // Delete all folders
        await prisma.moduleFolder.deleteMany({ where: { id: { in: allIds } } });
        // For each asset, check if it is now orphaned (no usages remain)
        const uniqueAssetIds = [...new Set(assetIds)];
        for (const assetId of uniqueAssetIds) {
            const usageCount = await prisma.mediaUsage.count({ where: { media_id: assetId } });
            if (usageCount === 0) {
                // Delete from object store and DB
                const asset = await prisma.mediaAsset.findUnique({ where: { id: assetId } });
                if (asset) {
                    try {
                        await cloudflareR2.deleteMediaFile(asset.media_path);
                    } catch (error) {
                        console.error('Cloudflare R2 deletion error:', error);
                    }
                    await prisma.mediaAsset.delete({ where: { id: assetId } });
                }
            }
        }
        return res.status(200).json({ message: "Folder, subfolders, usages, and orphaned assets deleted successfully" });
    } catch (error: any) {
        if (error.code === 'P2025') {
            return res.status(404).json({ message: "Folder not found" });
        }
        console.error('Delete folder error:', error);
        return res.status(500).json({ message: "Error deleting folder" });
    }
}
