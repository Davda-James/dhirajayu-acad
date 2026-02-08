import * as z from 'zod';
import { Role } from '@prisma/client';

export const updateRoleSchema = z.object({
    role: z.enum(Role)
}).strict();

export const getAllUsersSchema = z.object({
    page: z.number().int().min(1).optional(),
    pageSize: z.number().int().min(1).max(50).optional()
}).strict()

