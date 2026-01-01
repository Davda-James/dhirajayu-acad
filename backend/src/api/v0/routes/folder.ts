import Router from 'express';
import {
    createFolder,
    getFoldersByModule,
    getFoldersByParent,
    updateFolder,
    getRootFolders,
    deleteFolder
} from '@v0/controllers/folder';
import checkRoleisAdmin from '@/api/v0/middlewares/checkRole';
import { verifySession } from '../middlewares/auth';

const router = Router();

// All routes require authentication and admin role
router.post('/create', verifySession, checkRoleisAdmin, createFolder);
router.get('/module/:moduleId', verifySession, getFoldersByModule);
router.get('/children/:parentId', verifySession, getFoldersByParent);
router.get('/root/:moduleId', verifySession, getRootFolders);
router.put('/update', verifySession, checkRoleisAdmin, updateFolder);
router.delete('/:folderId', verifySession, checkRoleisAdmin, deleteFolder);

export default router;
