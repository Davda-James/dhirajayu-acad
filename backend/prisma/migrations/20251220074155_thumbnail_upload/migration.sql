/*
  Warnings:

  - You are about to drop the column `thumbnail_url` on the `Courses` table. All the data in the column will be lost.
  - You are about to drop the column `expires_at` on the `Orders` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "Courses" DROP COLUMN "thumbnail_url",
ADD COLUMN     "thumbnail_id" TEXT;

-- AlterTable
ALTER TABLE "Orders" DROP COLUMN "expires_at";

-- AddForeignKey
ALTER TABLE "Courses" ADD CONSTRAINT "Courses_thumbnail_id_fkey" FOREIGN KEY ("thumbnail_id") REFERENCES "MediaAsset"("id") ON DELETE SET NULL ON UPDATE CASCADE;
