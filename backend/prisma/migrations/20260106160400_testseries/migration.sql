-- CreateEnum
CREATE TYPE "MCQOption" AS ENUM ('A', 'B', 'C', 'D');

-- CreateEnum
CREATE TYPE "AttemptStatus" AS ENUM ('IN_PROGRESS', 'COMPLETED');

-- CreateTable
CREATE TABLE "Test" (
    "id" TEXT NOT NULL,
    "course_id" TEXT NOT NULL,
    "title" VARCHAR(255) NOT NULL,
    "total_marks" INTEGER NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Test_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Question" (
    "id" TEXT NOT NULL,
    "test_id" TEXT NOT NULL,
    "image_id" TEXT,
    "question_text" TEXT NOT NULL,
    "option_a" TEXT NOT NULL,
    "option_b" TEXT NOT NULL,
    "option_c" TEXT NOT NULL,
    "option_d" TEXT NOT NULL,
    "correct_option" "MCQOption" NOT NULL,
    "marks" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Question_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Attempt" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "test_id" TEXT NOT NULL,
    "score" INTEGER NOT NULL DEFAULT 0,
    "attempted_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status" "AttemptStatus" NOT NULL DEFAULT 'IN_PROGRESS',

    CONSTRAINT "Attempt_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AttemptAnswer" (
    "id" TEXT NOT NULL,
    "attempt_id" TEXT NOT NULL,
    "question_id" TEXT NOT NULL,
    "selected_option" "MCQOption" NOT NULL,
    "is_correct" BOOLEAN,

    CONSTRAINT "AttemptAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Question_image_id_key" ON "Question"("image_id");

-- CreateIndex
CREATE INDEX "Question_test_id_idx" ON "Question"("test_id");

-- CreateIndex
CREATE INDEX "Attempt_user_id_idx" ON "Attempt"("user_id");

-- CreateIndex
CREATE INDEX "Attempt_test_id_idx" ON "Attempt"("test_id");

-- CreateIndex
CREATE INDEX "AttemptAnswer_attempt_id_idx" ON "AttemptAnswer"("attempt_id");

-- CreateIndex
CREATE UNIQUE INDEX "AttemptAnswer_attempt_id_question_id_key" ON "AttemptAnswer"("attempt_id", "question_id");

-- AddForeignKey
ALTER TABLE "Test" ADD CONSTRAINT "Test_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "Courses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Question" ADD CONSTRAINT "Question_test_id_fkey" FOREIGN KEY ("test_id") REFERENCES "Test"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Question" ADD CONSTRAINT "Question_image_id_fkey" FOREIGN KEY ("image_id") REFERENCES "MediaAsset"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Attempt" ADD CONSTRAINT "Attempt_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Attempt" ADD CONSTRAINT "Attempt_test_id_fkey" FOREIGN KEY ("test_id") REFERENCES "Test"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AttemptAnswer" ADD CONSTRAINT "AttemptAnswer_attempt_id_fkey" FOREIGN KEY ("attempt_id") REFERENCES "Attempt"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AttemptAnswer" ADD CONSTRAINT "AttemptAnswer_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "Question"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
