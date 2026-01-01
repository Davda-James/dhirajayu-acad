import { Router } from 'express';
import { createMediaAsset, getMediaAccessToken, listMediaAssets } from '../controllers/mediaAsset';
import checkRoleIsAdmin from '@v0/middlewares/checkRole';
import { verifySession } from '../middlewares/auth';

const router = Router();

// Admin: Upload a new media asset
router.post('/create', verifySession, checkRoleIsAdmin, createMediaAsset);

// List all media assets
router.get('/', verifySession, checkRoleIsAdmin, listMediaAssets);
router.get('/:assetId/accessToken', verifySession, getMediaAccessToken);

export default router;
