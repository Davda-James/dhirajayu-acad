import z from 'zod';

export const getCoursesSchema  = z.object({
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(50).default(10),
    is_paid: z.preprocess((val) => {
        if (val === undefined) return undefined;
        if (val === 'true' || val === true) return true;
        if (val === 'false' || val === false) return false;
        return undefined;
    }, z.boolean().optional()),
    sort: z.enum(['most_recent', 'most_popular', 'price_asc', 'price_desc', 'a_z', 'z_a']).optional()
}).strict();

export const createCourseSchema = z.object({
    title: z.string().min(3),
    description: z.string(),
    is_paid: z.boolean(),
    price: z.number().optional(),
    thumbnail_id: z.cuid().optional()
}).strict();

export const updateCourseSchema = z.object({
    courseId: z.cuid(),
    title: z.string().min(3).optional(),
    description: z.string().optional(),
    is_paid: z.boolean().optional(),
    thumbnail_id: z.cuid().optional()
}).strict();

export const deleteCourseSchema = z.object({
    courseId: z.cuid()
}).strict();

