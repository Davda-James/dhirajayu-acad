-- AlterTable
ALTER TABLE "MediaAsset" ADD COLUMN     "is_for_gallery" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "GalleryVideos" (
    "id" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GalleryVideos_pkey" PRIMARY KEY ("id")
);
