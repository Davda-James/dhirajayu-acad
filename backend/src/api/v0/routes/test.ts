import Router from 'express';
import { addImageForQuestion, addQuestion, deleteQuestion, createTest, getTestAttemptQuesAns, listTestsByCourse, getTestAttempts, startTest, submitAttempt, questionsForTest, updateTest, getTestDetails, updateQuestion } from '@v0/controllers/test';
import checkRoleisAdmin from '@v0/middlewares/checkRole';
import { verifySession } from '@v0/middlewares/auth';

const router = Router();

router.post('/create', verifySession, checkRoleisAdmin, createTest);
router.put('/update-test/:testId', verifySession, checkRoleisAdmin, updateTest);
router.post('/ques-image-upload', verifySession, checkRoleisAdmin, addImageForQuestion);
router.post('/add-question', verifySession, checkRoleisAdmin, addQuestion);
router.put('/question/:questionId', verifySession, checkRoleisAdmin, updateQuestion);
router.delete('/question/:questionId', verifySession, checkRoleisAdmin, deleteQuestion);
router.get('/details/:testId', verifySession, getTestDetails);
router.get('/course/:courseId', verifySession, listTestsByCourse);
router.post('/start/:testId', verifySession, startTest);
router.get('/:testId/attempts', verifySession, getTestAttempts);
router.get('/attempt/:attemptId/questions', verifySession, getTestAttemptQuesAns);
router.post('/attempt/:attemptId/submit', verifySession, submitAttempt);
router.get('/get-questions/:testId', verifySession, checkRoleisAdmin, questionsForTest);

export default router;