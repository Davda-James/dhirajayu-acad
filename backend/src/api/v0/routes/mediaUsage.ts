import { Router } from 'express';
import { createMediaUsage, deleteMediaUsage, listMediaUsagesByFolder } from '../controllers/mediaUsage';
import checkRoleIsAdmin from '@v0/middlewares/checkRole';
import { verifySession } from '../middlewares/auth';

const router = Router();

// Admin: Place a media asset in a folder (create usage)
router.post('/create', verifySession, checkRoleIsAdmin, createMediaUsage);

// List usages for a folder
router.get('/folder/:folderId', verifySession ,listMediaUsagesByFolder);
router.delete('/delete/:usageId', verifySession, checkRoleIsAdmin, deleteMediaUsage);

export default router;
