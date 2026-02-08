import * as z from 'zod';
import { MediaType } from '@prisma/client';

export const createFolderSchema = z.object({
    moduleId: z.cuid(),
    title: z.string().min(1),
    description: z.string().optional(),
    parentId: z.cuid().nullable().optional()
}).strict();

export const getFolderByModuleSchema = z.object({
    moduleId: z.cuid()
}).strict();

export const getFolderByParentSchema = z.object({
    parentId: z.cuid()
}).strict();

export const getRootFoldersSchema = z.object({
    moduleId: z.cuid()
}).strict();

export const updateFolderSchema = z.object({
    folderId: z.cuid(),
    title: z.string().min(1).optional(),
    description: z.string().optional(),
    parentId: z.cuid().nullable().optional() // allow moving folder
}).strict();

export const deleteFolderSchema = z.object({
    folderId: z.cuid()
}).strict();


