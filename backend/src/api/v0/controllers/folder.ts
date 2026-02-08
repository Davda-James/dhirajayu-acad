import { Request, Response } from 'express';
import prisma from '@/shared/db';
import * as crypto from 'crypto';
import { cloudflareR2 } from '@v0/services/objectStore';
import { createFolderSchema, deleteFolderSchema, getFolderByModuleSchema, getFolderByParentSchema, getRootFoldersSchema, updateFolderSchema } from '@/shared/schema/folder';

export async function createFolder(req: Request, res: Response) {
    try {
        const parsedResult = createFolderSchema.safeParse(req.body);
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
    try {
        const parsedResult = getFolderByModuleSchema.safeParse(req.params);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid module ID" });
        }
        const { moduleId } = parsedResult.data;
        // Quick aggregate to create a lightweight ETag and avoid fetching/building the full tree when unchanged
        const stats = await prisma.moduleFolder.aggregate({
            where: { module_id: moduleId },
            _count: { id: true },
            _max: { updated_at: true, created_at: true }
        });
        const lastTS = stats._max.updated_at ?? stats._max.created_at;
        const quickSeed = `${stats._count.id}-${lastTS ? lastTS.toISOString() : ''}`;
        const quickEtag = crypto.createHash('sha1').update(quickSeed).digest('hex');
        const ifNoneMatch = req.headers['if-none-match'];
        if (ifNoneMatch) {
            if ((typeof ifNoneMatch === 'string' && ifNoneMatch === quickEtag) ||
                (Array.isArray(ifNoneMatch) && ifNoneMatch.includes(quickEtag))) {
                // Nothing changed since the last fetch according to aggregate, return 304
                return res.status(304).end();
            }
        }

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
        res.setHeader('ETag', quickEtag);
        return res.status(200).json({ folders: tree });
    } catch (error) {
        console.error('Get folders error:', error);
        return res.status(500).json({ message: "Error fetching folders" });
    }
}

// Get immediate child folders for a given folder
export async function getFoldersByParent(req: Request, res: Response) {
    try {
        const parsedResult = getFolderByParentSchema.safeParse(req.params);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid parent folder ID" });
        }
        const { parentId } = parsedResult.data;
        const children = await prisma.moduleFolder.findMany({
            where: { parent_id: parentId },
            include: { _count: { select: { mediaUsages: true } } },
            orderBy: { created_at: 'asc' }
        });
        const mapped = children.map(c => ({
            id: c.id,
            moduleId: c.module_id,
            title: c.title,
            description: c.description,
            mediaCount: c._count.mediaUsages,
            parentId: c.parent_id,
            createdAt: c.created_at
        }));

        // Compute ETag for this payload and support conditional GETs
        const etag = crypto.createHash('sha1').update(JSON.stringify(mapped)).digest('hex');
        const ifNoneMatch = req.headers['if-none-match'];
        if (ifNoneMatch) {
            if ((typeof ifNoneMatch === 'string' && ifNoneMatch === etag) ||
                (Array.isArray(ifNoneMatch) && ifNoneMatch.includes(etag))) {
                return res.status(304).end();
            }
        }
        res.setHeader('ETag', etag);

        return res.status(200).json({ folders: mapped });
    } catch (error) {
        console.error('Get child folders error:', error);
        return res.status(500).json({ message: "Error fetching child folders" });
    }
}

// Get root/top-level folders for a module
export async function getRootFolders(req: Request, res: Response) {
    try {
        const parsed = getRootFoldersSchema.safeParse(req.params);
        if (!parsed.success) {
            return res.status(400).json({ message: "Invalid module ID" });
        }
        const { moduleId } = parsed.data;

        const children = await prisma.moduleFolder.findMany({
            where: { module_id: moduleId, parent_id: null },
            include: { _count: { select: { mediaUsages: true } } },
            orderBy: { created_at: 'asc' }
        });

        const mapped = children.map(c => ({
            id: c.id,
            moduleId: c.module_id,
            title: c.title,
            description: c.description,
            mediaCount: c._count.mediaUsages,
            parentId: c.parent_id,
            createdAt: c.created_at
        }));

        // Compute ETag for this payload and support conditional GETs
        const etag = crypto.createHash('sha1').update(JSON.stringify(mapped)).digest('hex');
        const ifNoneMatch = req.headers['if-none-match'];
        if (ifNoneMatch) {
            if ((typeof ifNoneMatch === 'string' && ifNoneMatch === etag) ||
                (Array.isArray(ifNoneMatch) && ifNoneMatch.includes(etag))) {
                return res.status(304).end();
            }
        }
        res.setHeader('ETag', etag);

        return res.status(200).json({ folders: mapped });
    } catch (error) {
        console.error('Get root folders error:', error);
        return res.status(500).json({ message: "Error fetching root folders" });
    }
}

// Update Folder (allow moving in tree)
export async function updateFolder(req: Request, res: Response) {
    try {
        const parsedResult = updateFolderSchema.safeParse(req.body);
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
    try {
        const parsedResult = deleteFolderSchema.safeParse(req.params);
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
