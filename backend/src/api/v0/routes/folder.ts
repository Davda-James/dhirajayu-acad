import Router from 'express';
import {
    createFolder,
    getFoldersByModule,
    updateFolder,
    deleteFolder
} from '@v0/controllers/folder';
import checkRoleisAdmin from '@/api/v0/middlewares/checkRole';
import { verifySession } from '../middlewares/verifyToken';

const router = Router();

// All routes require authentication and admin role
router.post('/create', verifySession, checkRoleisAdmin, createFolder);
router.get('/module/:moduleId', verifySession, getFoldersByModule);
router.put('/update', verifySession, checkRoleisAdmin, updateFolder);
router.delete('/:folderId', verifySession, checkRoleisAdmin, deleteFolder);

export default router;
