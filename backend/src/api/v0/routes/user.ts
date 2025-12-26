import Router from 'express';
import { createUser, getAllUsers, getUserProfile, updateUserRole } from '@v0/controllers/user';
import checkRoleisAdmin from '@v0/middlewares/checkRole';
import { verifySession } from '@v0/middlewares/verifyToken';

const router = Router();

router.get('/profile', verifySession, getUserProfile);
router.post('/create', createUser);
//  can only be called by admin
router.post('/update-role', verifySession, checkRoleisAdmin, updateUserRole); 
router.get('/all-users', verifySession, checkRoleisAdmin, getAllUsers);

export default router;
