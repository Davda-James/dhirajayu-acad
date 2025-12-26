import type { Request, Response } from "express";
import { Role } from "@prisma/client";

export default async function checkRoleisAdmin(req: Request, res: Response, next: Function) {
    try {
        if (req.user.role !== Role.ADMIN) {
            return res.status(403).json({ message: "Forbidden: Unauthorized" });
        }      
        next();
    } catch (error) {   
        return res.status(401).json({ message: "Forbidden: Unauthorized" });
    }
}