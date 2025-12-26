import Router from 'express';
import {
  createCourse,
  updateCourse,
  deleteCourse,
  getAllCourses,
  addCourseLessons,
  requestMediaUpload,
  confirmMediaUpload,
  uploadThumbnail,
  isLoggedInUserEnrolled
} from '@v0/controllers/course';
import checkRoleisAdmin from '@v0/middlewares/checkRole';
import { verifySession } from '@v0/middlewares/verifyToken';

const router = Router();

// Admin routes - courses
router.post('/create-course', verifySession, checkRoleisAdmin, createCourse);
router.put('/update-course', verifySession, checkRoleisAdmin, updateCourse);
router.delete('/delete-course', verifySession, checkRoleisAdmin, deleteCourse);
router.get('/:courseId/add-lessons', verifySession, checkRoleisAdmin, addCourseLessons);


// Admin routes - media upload
router.post('/thumbnail/request-upload', verifySession, checkRoleisAdmin, uploadThumbnail);
router.post('/:courseId/request-upload', verifySession, checkRoleisAdmin, requestMediaUpload); 
router.post('/media/confirm-upload', verifySession, checkRoleisAdmin, confirmMediaUpload);

router.get('/get-all-courses', verifySession, getAllCourses);
router.get('/check_enrollment/:courseId', verifySession, isLoggedInUserEnrolled);

export default router;
