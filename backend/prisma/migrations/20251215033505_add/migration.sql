/*
  Warnings:

  - You are about to drop the `Media` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `updated_at` to the `Courses` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "MediaStatus" AS ENUM ('PENDING', 'UPLOADING', 'ACTIVE', 'FAILED', 'DELETED');

-- AlterEnum
ALTER TYPE "MediaType" ADD VALUE 'IMAGE';

-- DropForeignKey
ALTER TABLE "Media" DROP CONSTRAINT "Media_course_id_fkey";

-- AlterTable
ALTER TABLE "Courses" ADD COLUMN     "published" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "updated_at" TIMESTAMP(3) NOT NULL;

-- DropTable
DROP TABLE "Media";

-- CreateTable
CREATE TABLE "Modules" (
    "id" TEXT NOT NULL,
    "course_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,

    CONSTRAINT "Modules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ModuleFolder" (
    "id" TEXT NOT NULL,
    "module_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "parent_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ModuleFolder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MediaUsage" (
    "id" TEXT NOT NULL,
    "media_id" TEXT NOT NULL,
    "course_id" TEXT NOT NULL,
    "module_id" TEXT NOT NULL,
    "module_folder_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MediaUsage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MediaAsset" (
    "id" TEXT NOT NULL,
    "file_name" TEXT NOT NULL,
    "file_size" BIGINT NOT NULL,
    "mime_type" TEXT NOT NULL,
    "media_path" TEXT NOT NULL,
    "type" "MediaType" NOT NULL,
    "duration" INTEGER,
    "status" "MediaStatus" NOT NULL DEFAULT 'PENDING',
    "is_free_preview" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MediaAsset_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Modules_course_id_idx" ON "Modules"("course_id");

-- CreateIndex
CREATE UNIQUE INDEX "Modules_course_id_title_key" ON "Modules"("course_id", "title");

-- CreateIndex
CREATE INDEX "ModuleFolder_module_id_idx" ON "ModuleFolder"("module_id");

-- CreateIndex
CREATE INDEX "ModuleFolder_parent_id_idx" ON "ModuleFolder"("parent_id");

-- CreateIndex
CREATE INDEX "MediaUsage_media_id_idx" ON "MediaUsage"("media_id");

-- CreateIndex
CREATE INDEX "MediaUsage_course_id_idx" ON "MediaUsage"("course_id");

-- CreateIndex
CREATE INDEX "MediaUsage_module_id_idx" ON "MediaUsage"("module_id");

-- CreateIndex
CREATE INDEX "MediaUsage_module_folder_id_idx" ON "MediaUsage"("module_folder_id");

-- CreateIndex
CREATE INDEX "MediaUsage_order_idx" ON "MediaUsage"("order");

-- CreateIndex
CREATE UNIQUE INDEX "MediaAsset_media_path_key" ON "MediaAsset"("media_path");

-- CreateIndex
CREATE INDEX "MediaAsset_type_idx" ON "MediaAsset"("type");

-- CreateIndex
CREATE INDEX "MediaAsset_status_idx" ON "MediaAsset"("status");

-- AddForeignKey
ALTER TABLE "Modules" ADD CONSTRAINT "Modules_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "Courses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ModuleFolder" ADD CONSTRAINT "ModuleFolder_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "Modules"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ModuleFolder" ADD CONSTRAINT "ModuleFolder_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "ModuleFolder"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MediaUsage" ADD CONSTRAINT "MediaUsage_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "Courses"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MediaUsage" ADD CONSTRAINT "MediaUsage_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "Modules"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MediaUsage" ADD CONSTRAINT "MediaUsage_module_folder_id_fkey" FOREIGN KEY ("module_folder_id") REFERENCES "ModuleFolder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MediaUsage" ADD CONSTRAINT "MediaUsage_media_id_fkey" FOREIGN KEY ("media_id") REFERENCES "MediaAsset"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
