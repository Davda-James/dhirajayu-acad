import z from 'zod';

export const paginationSchema = z.object({
    page: z.string().optional(),
    pageSize: z.string().optional()
}).strict();
