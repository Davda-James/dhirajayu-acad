import { Router } from 'express';
import { createGalleryMediaImage, createGalleryMediaVideo, deleteGalleryMediaAsset, getMediaAccessToken, listGalleryMedia, requestGalleryImageUpload } from '@v0/controllers/mediaAsset';
import checkRoleIsAdmin from '@v0/middlewares/checkRole';
import { verifySession } from '@v0/middlewares/auth';

const router = Router();

// for gallery 
router.post('/upload-gallery-image', verifySession, checkRoleIsAdmin, createGalleryMediaImage);
router.post('/upload-gallery-video', verifySession, checkRoleIsAdmin, createGalleryMediaVideo);
router.post('/request-gallery-upload', verifySession, checkRoleIsAdmin, requestGalleryImageUpload);
router.get('/gallery', verifySession, listGalleryMedia);
router.delete('/gallery/:type/:assetId', verifySession, checkRoleIsAdmin, deleteGalleryMediaAsset);

router.get('/:assetId/accessToken', verifySession, getMediaAccessToken);
export default router;
