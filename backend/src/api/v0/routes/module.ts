import Router from 'express';
import {
    createModule,
    getModulesByCourse,
    updateModule,
    deleteModule
} from '@v0/controllers/module';
import checkRoleisAdmin from '@/api/v0/middlewares/checkRole';
import { verifySession } from '../middlewares/verifyToken';

const router = Router();

// All routes require authentication and admin role
router.post('/create', verifySession, checkRoleisAdmin, createModule);
router.get('/course/:courseId', verifySession, checkRoleisAdmin, getModulesByCourse);
router.put('/update', verifySession, checkRoleisAdmin, updateModule);
router.delete('/:moduleId', verifySession, checkRoleisAdmin, deleteModule);

export default router;
