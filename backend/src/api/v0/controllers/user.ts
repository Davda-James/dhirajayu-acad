import type { Request, Response } from 'express';
import prisma from '@/shared/db';
import { Role } from '@prisma/client'
import crypto from 'crypto';
import { getAllUsersSchema, updateRoleSchema } from '@/shared/schema/user';

function generateSessionId() {
  return crypto.randomUUID();
}

export async function createUser(req: Request, res: Response) {
    try {        
        const role = req.body?.role as Role | undefined;
        const device_id = req.headers['x-device-id'] as string;

        if (role && role !== Role.USER) {
            return res.status(403).json({ message: "Role can be assigned only by admin" });
        }

        // Check if user already exists
        const existingUser = await prisma.user.findUnique({
            where: { firebase_uid: req.user.firebase_id }
        });

        if (existingUser) {
            // User exists - update session and device (single device login)
            const newSessionId = generateSessionId();
            const updatedUser = await prisma.user.update({
                where: { firebase_uid: req.user.firebase_id },
                data: {
                    session_id: newSessionId,
                    device_id: device_id,
                    last_login: new Date(),
                }
            });

            return res.status(200).json({
                message: "Session updated",
                session_id: newSessionId,
                user: {
                    uid: updatedUser.firebase_uid,
                    email: updatedUser.email,
                    role: updatedUser.role
                }
            });
        }

        // Create new user
        const newSessionId = generateSessionId();
        const user = await prisma.user.create({
            data: {
                firebase_uid: req.user.firebase_id,
                session_id: newSessionId,
                device_id: device_id,
                role: Role.USER,
                email: req.user.email
            }
        });

        return res.status(201).json({
            message: "User created",
            session_id: newSessionId,
            user: {
                uid: user.firebase_uid,
                email: user.email,
                role: user.role
            }
        });
    } catch (error) {
        console.error('Error creating/updating user:', error);
        return res.status(500).json({ message: "Error creating user" });
    }
} 

export async function getUserProfile(req: Request, res: Response) {
    try {
        return res.status(200).json({
            session_id: req.headers['x-session-id'],
            user: {
                uid: req.user.firebase_id,
                email: req.user.email,
                role: req.user.role
            }
        });
    } catch(error) {
        return res.status(500).json({ message: "Error fetching user" });
    }
}

// Admin can promote other users (requires admin role)
export async function updateUserRole(req: Request, res: Response) {
    try {
        const parsedResult = updateRoleSchema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ 
                message: "Invalid input",
            });
        }

        const { role } = parsedResult.data;
        const user = await prisma.user.update({
            where: { firebase_uid: req.user.firebase_id },
            data: { role }
        });

        return res.status(200).json({
            message: "Role updated",
            user: {
                uid: user.firebase_uid,
                email: user.email,
                role: user.role
            }
        });
    } catch (error) {
        return res.status(500).json({ message: "Error updating user role" });
    }
}

export async function getAllUsers(req: Request, res: Response) {
    try {
        const parsedResult = getAllUsersSchema.safeParse(req.query);
        if (!parsedResult.success) {
            return res.status(400).json({ 
                message: "Invalid query parameters",
            });
        }
        const { page = 1, pageSize = 10 } = parsedResult.data;
        const users = await prisma.user.findMany({
            skip: (page - 1) * pageSize,
            take: pageSize,
            orderBy: { created_at: 'desc' },
        });
        return res.status(200).json({ users });
    } catch (error) {
        return res.status(500).json({ message: "Error fetching users" });
    }   
}
