
import type { Request, Response } from "express";
import { firebaseAdmin } from "@/shared/config/firebase";
import prisma from "@/shared/db";

export async function verifyToken(req: Request, res: Response, next: Function) {
    try {
        const token = req.headers.authorization?.split("Bearer ")[1];
        if (!token) {
            return res.status(401).json({ 
                message: "Unauthorized",
                code: "NO_TOKEN" 
            });
        }
        if(!req.headers['x-device-id']) {
            return res.status(401).json({
                message: "Unauthorized",
                code: "NO_DEVICE_ID"
            })
        }
        const decoded = await firebaseAdmin.auth().verifyIdToken(token);
        if(!decoded.email) {
            return res.status(401).json({ 
                message: "Unauthorized",
                code: "NO_EMAIL_IN_TOKEN" 
            }); 
        }
        req.user = { firebase_id: decoded.uid, email: decoded.email };
        next();
    } catch (error) {
        return res.status(401).json({ message: "Unauthorized" });
    }
}


export async function verifySession(req: Request, res: Response, next: Function) {
    try {    
        const device_id = req.headers['x-device-id'];
        const session_id = req.headers['x-session-id'];
        if (!session_id) {
            return res.status(400).json({ 
                message: "Session ID missing",
                code: "MISSING_SESSION_ID" 
            });
        }
        const { firebase_id } = req.user;

        const user = await prisma.user.findUnique({
            where: { firebase_uid: firebase_id },
            select: {
                id: true,
                firebase_uid: true,
                email: true,
                device_id: true,
                session_id: true,
                role: true,
                last_login: true
            }
        });
        if (!user) {
            return res.status(404).json({ 
                message: "User does not exist",
                code: "USER_NOT_FOUND" 
            });
        }
        if (user.device_id !== device_id || user.session_id !== session_id) {
            return res.status(401).json({ 
                message: "You have been logged in on another device",
                code: "SESSION_MISMATCH",
                reason: "logged_in_elsewhere"
            });
        }
        req.user = { uid: user.id , ...req.user, role: user.role };
        next();
    } catch (error) {
        return res.status(401).json({ message: "Unauthorized" });
    }
}   