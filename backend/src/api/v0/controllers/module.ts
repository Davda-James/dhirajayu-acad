import { Request, Response } from 'express';
import prisma from '@/shared/db';
import * as z from 'zod';

// Create Module
export async function createModule(req: Request, res: Response) {
    const schema = z.object({
        courseId: z.cuid(),
        title: z.string().min(1),
    }).strict();

    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ 
                message: "Invalid input",
                errors: parsedResult.error.issues 
            });
        }

        const { courseId, title } = parsedResult.data;

        // Verify course exists
        const course = await prisma.courses.findUnique({
            where: { id: courseId }
        });

        if (!course) {
            return res.status(404).json({ message: "Course not found" });
        }

        // Check for duplicate module title in the same course
        const existing = await prisma.modules.findFirst({
            where: {
                course_id: courseId,
                title: title,
            },
        });
        if (existing) {
            return res.status(409).json({ message: `A module named '${title}' already exists in this course.` });
        }

        const module = await prisma.modules.create({
            data: {
                course_id: courseId,
                title,
            }
        });

        return res.status(201).json({
            message: "Module created",
            module: {
                id: module.id,
                courseId: module.course_id,
                title: module.title
            }
        });
    } catch (error: any) {
        return res.status(500).json({ message: "Error creating module" });
    }
}

// Get Modules by Course
export async function getModulesByCourse(req: Request, res: Response) {
    const schema = z.object({
        courseId: z.cuid()
    }).strict();
    try {
        const parsedResult = schema.safeParse(req.params);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid course ID" });
        }

        const { courseId } = parsedResult.data;

        const modules = await prisma.modules.findMany({
            where: { course_id: courseId },
            include: {
                ModuleFolders: {
                    select: {
                        id: true,
                        title: true,
                        description: true
                    }
                },
                _count: {
                    select: { mediaUsages: true }
                }
            },
            orderBy: { id: 'asc' }
        });

        return res.status(200).json({
            modules: modules.map(m => ({
                id: m.id,
                courseId: m.course_id,
                title: m.title,
                folders: m.ModuleFolders,
                mediaCount: m._count.mediaUsages    
            }))
        });
    } catch (error) {
        return res.status(500).json({ message: "Error fetching modules" });
    }
}

// Update Module
export async function updateModule(req: Request, res: Response) {
    const schema = z.object({
        moduleId: z.cuid(),
        title: z.string().min(1)
    }).strict();

    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ 
                message: "Invalid input",
                errors: parsedResult.error.issues 
            });
        }

        const { moduleId, title } = parsedResult.data;

        const module = await prisma.modules.update({
            where: { id: moduleId },
            data: { title }
        });

        return res.status(200).json({
            message: "Module updated",
            module: {
                id: module.id,
                courseId: module.course_id,
                title: module.title
            }
        });
    } catch (error: any) {
        if (error.code === 'P2025') {
            return res.status(404).json({ message: "Module not found" });
        }
        if (error.code === 'P2002') {
            return res.status(409).json({ message: "Module with this title already exists in course" });
        }
        console.error('Update module error:', error);
        return res.status(500).json({ message: "Error updating module" });
    }
}

// Delete Module
export async function deleteModule(req: Request, res: Response) {
    const schema = z.object({
        moduleId: z.cuid()
    }).strict();

    try {
        const parsedResult = schema.safeParse(req.params);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid module ID" });
        }

        const { moduleId } = parsedResult.data;

        await prisma.modules.delete({
            where: { id: moduleId }
        });

        return res.status(200).json({ message: "Module deleted successfully" });
    } catch (error: any) {
        if (error.code === 'P2025') {
            return res.status(404).json({ message: "Module not found" });
        }
        console.error('Delete module error:', error);
        return res.status(500).json({ message: "Error deleting module" });
    }
}
