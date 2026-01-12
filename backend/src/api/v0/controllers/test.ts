import prisma from '@/shared/db';
import { imageUploadSchema } from '@/shared/schema/media';
import { addQuestionSchema, createTestSchema, updateTestSchema, submitAttemptSchema, updateQuestionSchema } from '@/shared/schema/test';
import {Request, Response} from 'express';
import mime from 'mime-types';
import crypto from 'crypto';
import { cloudflareR2 } from '@v0/services/objectStore';
import { AttemptStatus, MediaStatus, MediaType } from '@prisma/client';
import { Role } from '@prisma/client';
import ENV from '@/shared/config/env';

export async function createTest(req: Request, res: Response) {
    console.log("Create test request body:", req.body);
    const parsedResult = createTestSchema.safeParse(req.body);
    if (!parsedResult.success) {
        return res.status(400).json({ message: "Invalid input", errors: parsedResult.error.issues });
    }
    const { course_id, title, description, total_marks, duration } = parsedResult.data;
    try {
        const test = await prisma.test.create({
            data: {
                course_id,
                title,
                description: (description ? description : null),
                total_marks,
                duration
            }
        })
        return res.status(201).json({ message: "Test created successfully", test: test });
    } catch(error) {
        return res.status(500).json({ message: "Error creating test"});
    }
}
export async function updateTest(req: Request, res: Response) {
    try {
        const { testId } = req.params;
        if(!testId) {
            return res.status(400).json({ message: "Test ID is required"});
        }
        const parsedResult = updateTestSchema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid input", errors: parsedResult.error.issues });
        }
        const { title, description, total_marks, duration } = parsedResult.data;
        const existingTest = await prisma.test.findUnique({ where: { id: testId } });
        if(!existingTest) {
            return res.status(404).json({ message: "Test not found"});
        }

        const dataToUpdate: any = {};
        if (title !== undefined) dataToUpdate.title = title;
        if (description !== undefined) dataToUpdate.description = description ?? null;
        if (total_marks !== undefined) dataToUpdate.total_marks = total_marks;
        if (duration !== undefined) dataToUpdate.duration = duration;

        if (Object.keys(dataToUpdate).length === 0) {
            // Nothing to update
            return res.status(400).json({ message: 'No fields provided for update' });
        }

        const updatedTest = await prisma.test.update({
            where: { id: testId },
            data: dataToUpdate
        })
        return res.status(200).json({ message: "Test updated successfully", test: updatedTest });
    } catch(error) {
        console.error('Error in updateTest:', error);
        return res.status(500).json({ message: "Error updating test"});
    }
}

export async function addImageForQuestion(req: Request, res: Response) {
    try{
        const parsedResult = imageUploadSchema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid input", errors: parsedResult.error.issues });
        }
        const { fileName, fileSize, mimeType } = parsedResult.data.media;
        const questionImageId = crypto.randomUUID();
        const fileExtension = mime.extension(mimeType);
        if (!fileExtension) throw new Error("Unsupported MIME type");
        const uploadURL = await cloudflareR2.getPreSignedUploadUrl(`test/${questionImageId}.${fileExtension}`);

        const mediaAsset = await prisma.mediaAsset.create({
            data: {
                file_name: fileName,
                file_size: BigInt(fileSize),
                mime_type: mimeType,
                media_path: `test/${questionImageId}.${fileExtension}`,
                type: "IMAGE"
            }
        })        
        return res.status(200).json({
            message: 'Question Image Upload URL generated successfully',
            upload: {
                mediaId: mediaAsset.id,
                uploadUrl: uploadURL,
                fileName: fileName,
                mediaPath: `test/${questionImageId}.${fileExtension}`,
            }
        })
    } catch(error) {
        console.error("Error generating upload URL for test question image", error);
        return res.status(500).json({ message: "Error generating upload URL"});
    }
}

export async function addQuestion(req: Request, res: Response) {
    try{
        const parsedResult = addQuestionSchema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid input", errors: parsedResult.error.issues });
        }
        const { test_id, mediaId, question_text, marks, option_a, option_b, option_c, option_d, correct_option } = parsedResult.data;
        let question;
        if(mediaId) {
            const media = await prisma.mediaAsset.findUnique({ where: { id: mediaId } });
            if (!media) {
                return res.status(400).json({ message: "Invalid media ID"});
            }
            try {
                await cloudflareR2.checkFileExists(media.media_path);
            } catch (error) {
                await prisma.mediaAsset.delete({ where: { id: mediaId } });
                return res.status(400).json({ message: "Media file does not exist in storage"});
            }
            question = await prisma.$transaction(async (tx) => {
                const question = await tx.question.create({
                    data: {
                        test_id,
                        question_text,
                        marks,
                        option_a,
                        option_b,
                        option_c,
                        option_d,
                        correct_option,
                        image_id: mediaId
                    }
                });
                await tx.mediaAsset.update({
                    where: { id: mediaId },
                    data: { status: MediaStatus.ACTIVE }
                })
                return question;
            })
        } else {
            question = await prisma.question.create({
                data: {
                    test_id,
                    question_text,
                    marks,
                    option_a,
                    option_b,
                    option_c,
                    option_d,
                    correct_option
                }
            })        
        }
        return res.status(201).json({ message: "Question added successfully", question });
    } catch(error) {
        return res.status(500).json({ message: "Error adding question"});
    }
}

export async function updateQuestion(req: Request, res: Response) {
  try {
    const { questionId } = req.params;
    if (!questionId) {
      return res.status(400).json({ message: 'Question ID is required' });
    }

    const parsed = updateQuestionSchema.safeParse(req.body);
    if (!parsed.success) {
        console.log(parsed.error);
      return res.status(400).json({
        message: 'Invalid input',
        errors: parsed.error.flatten().fieldErrors
      });
    }
    console.log("reached step2")
    const {
      imageId,
      previous_imageId,
      removeImage,
      question_text,
      marks,
      option_a,
      option_b,
    option_c,
      option_d,
      correct_option
    } = parsed.data;

    const existingQuestion = await prisma.question.findUnique({
      where: { id: questionId }
    });

    if (!existingQuestion) {
      return res.status(404).json({ message: 'Question not found' });
    }

    const updateData: any = {};
    if (question_text !== undefined) updateData.question_text = question_text;
    if (marks !== undefined) updateData.marks = marks;
    if (option_a !== undefined) updateData.option_a = option_a;
    if (option_b !== undefined) updateData.option_b = option_b;
    if (option_c !== undefined) updateData.option_c = option_c;
    if (option_d !== undefined) updateData.option_d = option_d;
    if (correct_option !== undefined) updateData.correct_option = correct_option;

    // If nothing at all is changing
    if (
      Object.keys(updateData).length === 0 &&
      imageId === undefined &&
      !removeImage
    ) {
      return res.status(400).json({ message: 'No fields provided for update' });
    }

    console.log("something is there to change")
    let mediaPathToDelete: string | null = null;

    await prisma.$transaction(async (tx) => {
      // image removal
      if (removeImage) {
        if (!existingQuestion.image_id) {
          throw new Error('NO_IMAGE_TO_REMOVE');
        }

        if (previous_imageId !== existingQuestion.image_id) {
          throw new Error('PREVIOUS_IMAGE_MISMATCH');
        }

        const prevMedia = await tx.mediaAsset.findUnique({
          where: { id: previous_imageId }
        });

        if (prevMedia) {
            console.log("should not reach as prev media is not there")
          mediaPathToDelete = prevMedia.media_path;
          await tx.mediaAsset.delete({ where: { id: prevMedia.id } });
        }

        updateData.image_id = null;
      }

        // update question
      if (imageId) {
        const newMedia = await tx.mediaAsset.findUnique({
          where: { id: imageId }
        });
        console.log("image detected")
        if (!newMedia || newMedia.status !== MediaStatus.PENDING) {
          throw new Error('INVALID_NEW_MEDIA');
        }

        // Verify file exists in storage
        await cloudflareR2.checkFileExists(newMedia.media_path);

        // Replace old image if present
        if (existingQuestion.image_id) {
          if (previous_imageId !== existingQuestion.image_id) {
            throw new Error('PREVIOUS_IMAGE_MISMATCH');
          }

          const oldMedia = await tx.mediaAsset.findUnique({
            where: { id: previous_imageId }
          });

          if (oldMedia) {
            mediaPathToDelete = oldMedia.media_path;
            await tx.mediaAsset.delete({ where: { id: oldMedia.id } });
          }
        }

        // Activate new media
        await tx.mediaAsset.update({
          where: { id: imageId },
          data: { status: MediaStatus.ACTIVE }
        });

        updateData.image_id = imageId;
      }

        // update question
      if (Object.keys(updateData).length > 0) {
        await tx.question.update({
          where: { id: questionId },
          data: updateData
        });
      }
    });

    // object storage clean up
    if (mediaPathToDelete) {
      try {
        console.log("deleted old path ")
        await cloudflareR2.deleteMediaFile(mediaPathToDelete);
      } catch (err) {
        console.error('Failed to delete media from storage:', err);
      }
    }

    return res.status(200).json({ message: 'Question updated successfully' });

  } catch (error: any) {
    console.error('Error updating question:', error);

    switch (error.message) {
      case 'INVALID_NEW_MEDIA':
        return res.status(400).json({ message: 'New media asset is invalid or not ready' });
      case 'PREVIOUS_IMAGE_MISMATCH':
        return res.status(400).json({ message: 'previous_imageId does not match current image' });
      case 'NO_IMAGE_TO_REMOVE':
        return res.status(400).json({ message: 'No image exists to remove' });
      default:
        return res.status(500).json({ message: 'Error updating question' });
    }
  }
}


export async function deleteQuestion(req: Request, res: Response) {
    try {
        const { questionId } = req.params;
        if(!questionId) {
            return res.status(400).json({ message: "Question ID is required"});
        }
        const existingQuestion = await prisma.question.findUnique({ where: { id: questionId } });
        if(!existingQuestion) {
            return res.status(404).json({ message: "Question not found"});
        }
        await prisma.question.delete({ where: { id: questionId } });
        return res.status(200).json({ message: "Question deleted successfully" });
    } catch (error) {
        console.error("Error deleting question", error);
        return res.status(500).json({ message: "Error deleting question" });
    }
}

export async function getTestDetails(req: Request, res: Response) {
    try {
        const { testId } = req.params;
        if(!testId) {
            return res.status(400).json({ message: "Test ID is required"});
        }
        const test = await prisma.test.findUnique({
            where: { id: testId }
        });
        if(!test) {
            return res.status(404).json({ message: "Test not found"});
        }
        return res.status(200).json({ test });
    } catch(error) {
        console.error("Error fetching test details", error);
        return res.status(500).json({ message: "Error fetching test details"});
    }
}

async function checkIsUserEnrolledInCourse(userId: string, courseId: string): Promise<boolean> {
    const isEnrolled = await prisma.enrollments.findFirst({
        where: {
            user_id: userId,
            course_id: courseId,
        }
    });
    return isEnrolled ? true : false;
}

export async function startTest(req: Request, res: Response) {
    try {
        const { testId } = req.params;
        if(!testId) {
            return res.status(400).json({ message: "Test ID is required"});
        }

        const test = await prisma.test.findUnique({
            where: { id: testId },
            include: { course: true, questions: { include: { image: { select: { media_path: true } } }, omit: { correct_option: true} } }
        });
        if(!test) {
            return res.status(404).json({ message: "Test not found"});
        }
        if (req.user.role! !== Role.ADMIN && test.course.is_paid) {
            if (!(await checkIsUserEnrolledInCourse(req.user.uid!, test.course_id))) {
                return res.status(403).json({ message: 'Access denied to this test' });
            }
        }
        const createdAttempt = await prisma.attempt.create({
            data: {
                user_id: req.user.uid!,
                test_id: test.id,
            }
        })
        return res.status(200).json({
            message: "Test started",
            attemptId: createdAttempt.id,
            test: {
                ...test,
            }
        });
    } catch(error) {
        return res.status(500).json({ message: "Error starting test"});
    }   
}

export async function getTestAttempts(req: Request, res: Response) {
    try {
        const { testId } = req.params;
        if(!testId) {
            return res.status(400).json({ message: "Test ID is required"});
        }
        const test = await prisma.test.findUnique({
            where: { id: testId },
            select: {
                course_id: true,
                course: {
                select: {
                    is_paid: true
                }
                }
            }
        });
        if (!test) {
            return res.status(404).json({ message: "Test not found" });
        }
        if (req.user.role! !== Role.ADMIN && test.course.is_paid) {
            if(!(await checkIsUserEnrolledInCourse(req.user.uid!, test.course_id))) {
                return res.status(403).json({ message: 'Access denied, purchase the course to access test' });
            }
        }
        const attempts = await prisma.attempt.findMany({
            where: { user_id: req.user.uid! , test_id: testId },
            omit: {
                user_id: true,
            },
            orderBy: {
                attempted_at: 'desc'
            }
        });
        
        return res.status(200).json({ attempts });
    } catch(error) {
        return res.status(500).json({ message: "Error fetching test attempts"});
    }
}     

export async function getTestAttemptQuesAns(req: Request, res: Response) {
    try {
        const { attemptId } = req.params;
        if(!attemptId) {
            return res.status(400).json({ message: "Attempt ID is required"});
        }
        const attempt = await prisma.attempt.findFirst({
            where: { id: attemptId, user_id: req.user.uid!, status: AttemptStatus.COMPLETED },
            select: { 
                id: true,
                score: true,
                attempted_at: true,
                test: {
                select: {
                    course_id: true,
                    course: {
                       select: { is_paid: true }
                    }
                }
            }}
        })
        if(!attempt) {
            return res.status(404).json({ message: "Test attempt not found for logged in user"});
        }
        if(req.user.role! !== Role.ADMIN && attempt?.test.course.is_paid) {
            if(!(await checkIsUserEnrolledInCourse(req.user.uid!, attempt.test.course_id))) {
                return res.status(403).json({ message: 'Access denied to this test attempt' });
            }
        }
        const answers = await prisma.attemptAnswer.findMany({
            where: {
                attempt_id: attemptId
            },
            include: {
                question: {
                    select: {
                        id: true,
                        question_text: true,
                        option_a: true,
                        option_b: true,
                        option_c: true,
                        option_d: true,
                        marks: true,
                        image_id: true,
                        correct_option: true
                    }
                }
            },
            orderBy: {
                question: { created_at: "asc" }
            }
        })
        return res.status(200).json({
            attempt: {
                id: attempt.id,
                score: attempt.score,
                attempted_at: attempt.attempted_at
            },
            questions: answers.map(a => ({
                ...a.question,
                selected_option: a.selected_option,
                is_correct: a.is_correct
            }))
        });
    } catch(error) {    
        return res.status(500).json({ message: "Error fetching test attempt questions"});
    } 
}

export async function submitAttempt(req: Request, res: Response) {
    try {
        const { attemptId } = req.params;
        if(!attemptId) {
            return res.status(400).json({ message: "Attempt ID is required"});
        }
        const parsedResult = submitAttemptSchema.safeParse(req.body);
        if (!parsedResult.success) {
            return res.status(400).json({ message: "Invalid input", errors: parsedResult.error.issues });
        }
        const { answers } = parsedResult.data;
        const attempt = await prisma.attempt.findFirst({
            where: { id: attemptId, user_id: req.user.uid!, status: AttemptStatus.IN_PROGRESS },
            select: {
                id: true,
                test_id: true
            }
        })
        if(!attempt) {
            return res.status(404).json({ message: "Test attempt not found for logged in user"});
        }
        const questions = await prisma.question.findMany({
            where: { test_id: attempt.test_id },
            select: {
                id: true,
                correct_option: true,
                marks: true
            }
        });
        
        const validQuestionIds = new Set(questions.map(q => q.id));
        const invalidIds = Object.keys(answers).filter(id => !validQuestionIds.has(id));
        
        if (invalidIds.length > 0) {
            return res.status(400).json({ 
                message: "Invalid question IDs submitted",
                invalidIds 
            });
        }

        let totalScore = 0;

        const attemptAnswers = questions
        .map(question => {
            const selected = answers[question.id];
            if (!selected) return null;

            const isCorrect = selected === question.correct_option;
            if (isCorrect) totalScore += question.marks;

            return {
                attempt_id: attempt.id,
                question_id: question.id,
                selected_option: selected,
                is_correct: isCorrect
            };
        })
        .filter(Boolean) as {
            attempt_id: string;
            question_id: string;
            selected_option: 'A' | 'B' | 'C' | 'D';
            is_correct: boolean;
        }[];

        await prisma.$transaction([
            prisma.attemptAnswer.createMany({
                data: attemptAnswers,
                skipDuplicates: true
            }),
            prisma.attempt.update({
                where: { id: attempt.id },
                data: {
                    score: totalScore,
                    status: AttemptStatus.COMPLETED
                }
            })
        ]);

        return res.status(200).json({
            message: "Test submitted successfully",
            score: totalScore
        });

    } catch(error) {
        console.error("Error submitting test attempt", error);
        return res.status(500).json({ message: "Error fetching tests"});
    }
}

export async function listTestsByCourse(req: Request, res: Response) {
    try {
        const { courseId } = req.params;
        if(!courseId) {
            return res.status(404).json({ message: "Course ID is required" });
        }
        const tests = await prisma.test.findMany({
            where: { course_id: courseId },
            orderBy: { created_at: 'desc'}
        })
    return res.status(200).json({ tests });
            
    } catch(error) {
        console.error("Error fetching tests by course", error);
        return res.status(500).json({ message: "Error fetching tests"});
    }
}

export async function questionsForTest(req: Request, res: Response) {
    try {
        const { testId } = req.params;
        if(!testId) {
            return res.status(404).json({ message: "Test ID is required" });
        }
        const questions = await prisma.question.findMany({
            where: { test_id: testId },
            orderBy: { created_at: 'asc' }
        })
        return res.status(200).json({ questions });
    } catch (error) {
        console.error("Error fetching questions for test", error);
        return res.status(500).json({ message: "Error fetching questions for test" });
    }
}