import z from "zod"

export const createTestSchema = z.object({
    course_id: z.cuid(),
    title: z.string().min(1).max(255),
    description: z.string().optional(),
    total_marks: z.number().int().min(0),
    duration: z.number().int().positive(),
    negative_marks: z.number().nonnegative().optional()
});

export const updateTestSchema = z.object({
    title: z.string().min(1).max(255).optional(),
    description: z.string().optional(),
    total_marks: z.number().int().min(0).optional(),
    duration: z.number().int().positive().optional(),
    negative_marks: z.number().nonnegative().optional()
})

export const addQuestionSchema = z.object({
  test_id: z.cuid(),
  mediaId: z.cuid().optional(),
  marks: z.number().int().positive().optional(),
  question_text: z.string().min(1),
  option_a: z.string().min(1),
  option_b: z.string().min(1),
  option_c: z.string().min(1),
  option_d: z.string().min(1),
  correct_option: z.enum(['A', 'B', 'C', 'D'])
}).strict();

export const updateQuestionSchema = z.object({
  imageId: z.cuid().optional(),
  previous_imageId: z.cuid().optional(),
  removeImage: z.boolean().optional(),

  question_text: z.string().min(1).optional(),
  marks: z.number().int().min(0).optional(),
  option_a: z.string().min(1).optional(),
  option_b: z.string().min(1).optional(),
  option_c: z.string().min(1).optional(),
  option_d: z.string().min(1).optional(),
  correct_option: z.enum(['A', 'B', 'C', 'D']).optional()
}).superRefine((data, ctx) => {
  if (data.removeImage && data.imageId) {
    ctx.addIssue({
      code: 'custom',
      path: ['imageId'],
      message: 'Cannot provide imageId when removeImage is true'
    });
  }

  if (data.removeImage && !data.previous_imageId) {
    ctx.addIssue({
      code: 'custom',
      path: ['previous_imageId'],
      message: 'previous_imageId is required when removing image'
    });
  }
});

export const deleteQuestionSchema = z.object({
  question_id: z.cuid()
}).strict();

export const submitAttemptSchema = z.object({
  answers: z.record(z.cuid(), z.enum(['A', 'B', 'C', 'D']))
}).strict();

