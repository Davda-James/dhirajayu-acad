import Router from "express";
import { Request, Response } from 'express';
import prisma from "@/shared/db";
import { MediaType, MediaStatus, PaymentStatus, OrderStatus } from "@prisma/client";
import * as z from "zod";
import ENV from "@/shared/config/env";
import mime from "mime-types";
import { SignJWT } from 'jose';
import { cloudflareR2 } from '@v0/services/objectStore';
import razorpay from "@/shared/config/razorpay";
import crypto from "crypto";
import { signWithJWT } from "../utils/mediaSigner";

const router = Router();

// Validation constants
const MAX_FILE_SIZE = 1000 * 1024 * 1024; // 1GB
const ALLOWED_MIME_TYPES = [
    'video/mp4', 'video/quicktime', 'video/x-msvideo',
    'audio/mpeg', 'audio/wav', 'audio/ogg',
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg', 'image/png', 'image/webp'
];
const IMAGE_MIME_TYPES = ['image/jpeg', 'image/png','image/jpg', 'image/webp'];
const MAX_BATCH_SIZE = 10;

// has paging
export async function getAllCourses(req: Request, res: Response) {
    const paginationSchema = z.object({
            page: z.coerce.number().int().min(1).default(1),
            pageSize: z.coerce.number().int().min(1).max(50).default(10),
            is_paid: z.preprocess((val) => {
                if (val === undefined) return undefined;
                if (val === 'true' || val === true) return true;
                if (val === 'false' || val === false) return false;
                return undefined;
            }, z.boolean().optional())
    }).strict();
    try {
        const parsedResult = paginationSchema.safeParse(req.query);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid query parameters", errors: parsedResult.error.issues });
        }
        // Parse pagination params
        const { page, pageSize, is_paid } = parsedResult.data;
        const skip = (page - 1) * pageSize;

        const whereClause: any = {};
        console.log(req.query)
        if (typeof is_paid === 'boolean') {
            whereClause.is_paid = is_paid;
        }
        console.log(whereClause)

        // Get total count for pagination
            const [total, courses] = await Promise.all([
                prisma.courses.count({ where: whereClause }),
                prisma.courses.findMany({
                    where: whereClause,
                    skip,
                    take: pageSize,
                    orderBy: { created_at: 'desc' },
                    include: {
                        thumbnail: {
                            select: { id: true, media_path: true, mime_type: true }
                        },
                    }
                })
            ])
            // Map thumbnail.media_path to full worker URL so frontend can render via worker
            const mapped = courses.map(c => {
                const course = { ...c } as any;
                if (course.thumbnail && course.thumbnail.media_path) {
                    const base = ENV.WORKER_BASE_URL;
                    course.thumbnail_url = `${base}/${course.thumbnail.media_path}`;
                } else {
                    course.thumbnail_url = null;
                }
                // remove nested thumbnail object to keep response compact
                delete course.thumbnail;
                return course;
            });
            console.log(mapped);
        return res.status(200).json({   
            data: mapped,
            page,
            pageSize,
            total,
            totalPages: Math.ceil(total / pageSize)
        });
    } catch (error) {
        return res.status(500).json({ message: "Error fetching courses" });
    }
}


export async function createCourse(req: Request, res: Response) {
    const schema = z.object({
        title: z.string().min(3),
        description: z.string(),
        is_paid: z.boolean(),
        price: z.number().optional(),
        mediaId: z.cuid().optional()
    }).strict();
    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid input" });
        }
        let payload = parsedResult.data;

        // If is_paid is true, price is required
        if (payload.is_paid && !payload.price) {
            return res.status(400).json({ message: "Price is required for paid courses" });
        }

        const course = await prisma.courses.create({
            data: {
                title: payload.title,
                description: payload.description,
                is_paid: payload.is_paid,
                price: payload.price || null,
                thumbnail_id: payload.mediaId || null,
                published: false
            }
        });

        return res.status(201).json({
            message: "Course created",
            course: {
                id: course.id,
                title: course.title,
                description: course.description,
                is_paid: course.is_paid,
                price: course.price,
                published: course.published
            }
        });
    } catch (error) {
        return res.status(500).json({ message: "Error creating course" });
    }
}

export async function updateCourse(req: Request, res: Response) {
    const schema = z.object({
        courseId: z.cuid(),
        title: z.string().min(3).optional(),
        description: z.string().optional(),
        is_paid: z.boolean().optional(),
        thumbnail_id: z.string().cuid().optional()
    }).strict();

    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid input" });
        }
        const { courseId, title, description, is_paid } = parsedResult.data;
        const updateData: Record<string, any> = {};
        if (title !== undefined) updateData.title = title;
        if (description !== undefined) updateData.description = description;
        if (is_paid !== undefined) updateData.is_paid = is_paid;

        if (Object.keys(updateData).length === 0) {
            return res.status(400).json({ message: "No fields to update" });
        }

        const course = await prisma.courses.update({
            where: { id: courseId },
            data: updateData
        });
        return res.status(200).json({
            message: "Course updated",
            course: {
                id: course.id,
                title: course.title,
                description: course.description,
                is_paid: course.is_paid
            }
        });
    } catch(error) {
        return res.status(500).json({ message: "Error updating course" });
    }
}

export async function deleteCourse(req: Request, res: Response) {
    const schema = z.object({
        courseId: z.cuid()
    }).strict();
    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid input" });
        }
        const courseId = parsedResult.data.courseId;
        await prisma.courses.delete({
            where: { id: courseId }
        });
        return res.status(200).json({ message: "Course deleted" });
    } catch (error) {
        return res.status(500).json({ message: "Error deleting course" });
    }
}

export async function addCourseLessons(req: Request, res: Response) {
    const schema = z.object({
        courseId: z.cuid(),
        lessons: z.array(z.object({
            title: z.string().min(3),
            description: z.string(),
        }))
    }).strict();
    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid input" });
        }

    } catch(error) {

    }
}

// Thumbnail upload controller (no courseId required)
export async function uploadThumbnail(req: Request, res: Response) {
    const schema = z.object({
        media: z.object({
            fileName: z.string(),
            fileSize: z.number().max(MAX_FILE_SIZE),
            mimeType: z.string().refine(val => IMAGE_MIME_TYPES.includes(val)),
            type: z.literal('IMAGE'),
            title: z.string().min(1),
            description: z.string().optional(),
            duration: z.number().optional()
        })
    }).strict();

    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            console.error('Thumbnail upload validation errors:', parsedResult.error.issues);
            return res.status(400).json({
                message: 'Invalid input',
                errors: parsedResult.error.issues
            });
        }
        const { media } = parsedResult.data;
        if(!media) {
            console.error('No media item provided in payload');
            return res.status(400).json({ message: 'No media item provided' });
        }

        const thumbnailId = crypto.randomUUID();
        const fileExtension = mime.extension(media.mimeType);
        if (!fileExtension) throw new Error("Unsupported MIME type");
        const uploadURL = await cloudflareR2.getPreSignedUploadUrl(`thumbnails/${thumbnailId}.${fileExtension}`);
        const createdMediaAsset = await prisma.mediaAsset.create({
            data: {
                file_name: media.fileName,
                file_size: media.fileSize,
                mime_type: media.mimeType,
                media_path: `thumbnails/${thumbnailId}.${fileExtension}`,
                type: 'IMAGE',
                status: MediaStatus.PENDING
            }
        });
        return res.status(200).json({
            message: 'Thumbnail upload URL generated',
            upload: {
                mediaId: createdMediaAsset.id,
                uploadUrl: uploadURL,
                fileName: media.fileName,
                mediaPath: `thumbnails/${thumbnailId}.${fileExtension}`,
            }
        });
    } catch (error) {
        console.error('Thumbnail upload error:', error);
    return res.status(500).json({ message: 'Error generating thumbnail upload URL', error: error instanceof Error ? error.message : error });
    }
}

function getMediaFolder(mediaType: string): string {
    const folderMap: Record<string, string> = {
        'VIDEO': 'videos',
        'AUDIO': 'audios',
        'DOCUMENT': 'docs',
        'IMAGE': 'thumbnails'
    };

    return folderMap[mediaType] || 'others';
}

// Admin Media Upload Functions
export async function requestMediaUpload(req: Request, res: Response) {
    const schema = z.object({
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
    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({
                message: "Invalid input",
                errors: parsedResult.error.issues
            });
        }
        
        const { courseId, moduleId, moduleFolderId, media } = parsedResult.data;

        // Verify course exists
        const course = await prisma.courses.findUnique({
            where: { id: courseId }
        });

        if (!course) {
            return res.status(404).json({ message: "Course not found" });
        }

        // Get max order for new media
        const maxOrder = await prisma.mediaUsage.findFirst({
            where: { course_id: courseId },
            orderBy: { order: 'desc' },
            select: { order: true }
        });

        const startOrder = (maxOrder?.order || 0) + 1;

        // Generate upload URLs and create pending media records
        const uploadData = await Promise.all(
            media.map(async (item, index) => {
                const fileExtension = mime.extension(item.mimeType);
                if (!fileExtension) throw new Error("Unsupported MIME type");
                const randomMediaUUID = crypto.randomUUID();
                const uniquePath = `courses-content/${getMediaFolder(item.type)}/${randomMediaUUID}.${fileExtension}`;

                const uploadURL = await cloudflareR2.getPreSignedUploadUrl(uniquePath);
                const result = await prisma.$transaction(async (prismaTx) => {
                const createdMediaAsset = await prismaTx.mediaAsset.create({
                    data: {
                        file_name: item.fileName,
                        file_size: item.fileSize,
                        mime_type: item.mimeType,
                        media_path: uniquePath,
                        type: item.type,
                        duration: item.duration || null,
                        status: MediaStatus.PENDING
                    }
                });
                const mediaUsage = await prismaTx.mediaUsage.create({
                    data: {
                        media_id: createdMediaAsset.id,
                        course_id: courseId,
                        module_id: moduleId,
                        module_folder_id: moduleFolderId,
                        title: item.title,
                        description: item.description || '',
                        order: startOrder + index
                    }
                });
                return { createdMediaAsset, mediaUsage };
            });

            console.log('Transaction result:', result);
            if (!result.createdMediaAsset || !result.mediaUsage) {
                throw new Error('Transaction failed to create media asset or usage');
            }
            return {
                mediaId: result.createdMediaAsset.id,
                usageId: result.mediaUsage.id,
                uploadUrl: uploadURL,
                fileName: item.fileName,
                mediaPath: uniquePath,
            };
        })
        );
        return res.status(200).json({
            message: "Upload URLs generated",
            uploads: uploadData
        });

    } catch (error) {
        return res.status(500).json({ message: "Error generating upload URLs" });
    }
}

export async function confirmMediaUpload(req: Request, res: Response) {
    const schema = z.object({
        mediaIds: z.array(z.cuid()).min(1).max(MAX_BATCH_SIZE)
    }).strict();

    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({
                message: "Invalid input",
                errors: parsedResult.error.issues
            });
        }

        const { mediaIds } = parsedResult.data;

        // Verify all media records exist and are pending
        const mediaRecords = await prisma.mediaAsset.findMany({
            where: {
                id: { in: mediaIds },
                status: MediaStatus.PENDING
            }
        });
        if (mediaRecords.length !== mediaIds.length) {
            return res.status(400).json({
                message: "Some media records not found or not in pending state"
            });
        }

        // Mark all as active
        await prisma.mediaAsset.updateMany({
            where: { id: { in: mediaIds } },
            data: {
                status: MediaStatus.ACTIVE
            }
        });
        return res.status(200).json({
            message: "Media confirmed and activated",
            count: mediaIds.length
        });

    } catch (error) {
        console.error('Confirm media error:', error);
        return res.status(500).json({ message: "Error confirming media upload" });
    }
}

export async function fetch_free_courses(req: Request, res: Response) {
    const schema = z.object({
        page: z.coerce.number().int().optional(),
        pageSize: z.coerce.number().int().optional()
    }).strict();
    try {
        const parsedResult = schema.safeParse(req.query);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid query parameters" });
        }
        const { page = 1, pageSize = 10 } = parsedResult.data;
        const skip = (page - 1) * pageSize;

        const free_medias = await prisma.mediaAsset.findMany({
            where: {
                status: MediaStatus.ACTIVE,
                is_free_preview: true
            },
            skip: skip,
            take: pageSize,
        })
        // Map media paths to worker URLs; client will call the worker with Authorization header
        free_medias.map(lesson => {
            const mediaUrl = `${ENV.WORKER_BASE_URL}/${lesson.media_path}`;
            lesson.media_path = mediaUrl;
        })
        return res.status(200).json({
            message: "Free courses fetched successfully",
            data: free_medias
        });
    } catch (error) {
        return res.status(500).json({ message: "Error fetching free courses" });
    }
}

async function createRazorpayOrder(amount: number, currency: string, userId: string, courseId: string) {
    try {
        const result = await prisma.$transaction(async (prismaTx) => {
            const order = await razorpay.orders.create({
                amount: amount,
                currency: currency,
            });

            const result =  await prismaTx.orders.create({
                data: {
                    order_id: order.id,
                    user_id: userId,
                    course_id: courseId,
                    amount: amount,
                    currency: currency,
                    status: OrderStatus.CREATED
                }
            });
            return result;
        });
        return result;
    } catch (error) {
        throw error;
    }
}

export async function buy_course(req: Request, res: Response) {
    const schema = z.object({
        courseId: z.cuid(),
        amount: z.number().min(1),
        currency: z.string().length(3),
    }).strict();
    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid input" });
        }
        const { courseId, amount, currency } = parsedResult.data;

        const course = await prisma.courses.findUnique({ where : { id : courseId } });
        if (!course) {
            return res.status(404).json({ message: "Course not found" });
        }

        // payment logic goes over here
        const result = await createRazorpayOrder(amount, currency, req.user.uid!, courseId);
        return res.status(200).json({
            message: "Razorpay order created",
            order: result
        });
    } catch (error) {
        return res.status(500).json({ message: "Error processing course purchase" });
    }
}

export async function verifyPayment(req: Request, res: Response) {
    const schema = z.object({
        order_id: z.string(),
        payment_id: z.string(),
        signature: z.string(),
        courseId: z.cuid()
    }).strict();

    try {
        const parsedResult = schema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid input" });
        }
        const { order_id, payment_id, signature, courseId } = parsedResult.data;
        const order = await prisma.orders.findUnique({
            where: { order_id: order_id }
        });
        if (!order) {
            return res.status(404).json({ message: "Order not found" });
        }
        // verify signature
        const generatedSignature = crypto.createHmac('sha256', ENV.RAZORPAY_KEY_SECRET)
            .update(order_id + '|' + payment_id)
            .digest('hex');
        if (generatedSignature !== signature) {
            return res.status(400).json({ message: "Invalid signature" });
        }
        const updatedOrder = await prisma.$transaction(async (prismaTx) => {
            // update order status
            const updatedOrder = await prisma.orders.update({
                where: { order_id: order_id },
                data: { status: OrderStatus.PAID }
            });

            await prisma.payments.create({
                data: {
                    order_id: updatedOrder.order_id,
                    payment_id: payment_id,
                    status: PaymentStatus.SUCCESS,
                    paid_at: new Date()
                }
            });
            await prismaTx.enrollments.create({
                data: {
                    user_id: order.user_id,
                    course_id: courseId,
                    enrolled_at: new Date()
                }
            });

            return updatedOrder;
        });
        return res.status(200).json({
            message: "Payment verified and enrolled successfully",
            order: updatedOrder
        });

    } catch (error) {
        return res.status(500).json({ message: "Error verifying payment" });
    }
}

export async function isLoggedInUserEnrolled(req: Request, res: Response) {
    const schema = z.object({
        courseId: z.cuid()
    });
    try {
        let parsedResult = schema.safeParse(req.params);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid course ID" });
        }
        const { courseId } = parsedResult.data;
        const enrollment = await prisma.enrollments.findFirst({
            where: {
                user_id: req.user.uid!,
                course_id: courseId
            }
        });
        return res.status(200).json({ enrolled: enrollment !== null });
    } catch (error) {
        return res.status(500).json({ message: "Error fetching course details" });
    }
}

export default router;
