import Router from 'express';
import {
    createModule,
    getModulesByCourse,
    updateModule,
    deleteModule
} from '@v0/controllers/module';
import checkRoleisAdmin from '@/api/v0/middlewares/checkRole';
import { verifySession } from '../middlewares/auth';

const router = Router();

// All routes require authentication and admin role
router.post('/create', verifySession, checkRoleisAdmin, createModule);
router.put('/update', verifySession, checkRoleisAdmin, updateModule);
router.delete('/:moduleId', verifySession, checkRoleisAdmin, deleteModule);

// can be used by users too
router.get('/course/:courseId', verifySession, getModulesByCourse);

export default router;
