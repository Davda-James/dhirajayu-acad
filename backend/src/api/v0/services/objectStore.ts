// import B2 from 'backblaze-b2';
// import crypto from 'crypto';
import ENV from '@/shared/config/env';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';   
import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { ObjectStore } from '@v0/services/types'; 


class CloudflareR2 implements ObjectStore {
    private client: S3Client;
    private bucketName: string;
    
    constructor(bucketName: string, accessKeyId: string, accessKeySecret: string, endpoint: string) {
        this.bucketName = bucketName;
        this.client = new S3Client({
            region: 'auto',
            endpoint: endpoint,
            credentials: {
                accessKeyId: accessKeyId,
                secretAccessKey: accessKeySecret,
            }
        });
    }

    async getPreSignedUploadUrl(fileKey: string, expiresInSeconds: number = 3600): Promise<string> {
        try {
            const command = new PutObjectCommand({
                Bucket: this.bucketName,
                Key: fileKey,
            });
            return await getSignedUrl(this.client, command, { expiresIn: expiresInSeconds });
        } catch (error) {
            throw new Error(`Error generating pre-signed upload URL: ${error}`);
        }
    }

    async deleteMediaFile(fileKey: string): Promise<boolean> {
        try {
            const command = new DeleteObjectCommand({
                Bucket: this.bucketName,
                Key: fileKey,
            });
            await this.client.send(command);
            return true;
        } catch (error) {
            throw new Error(`Error deleting media file: ${error}`);
        }
    }
}

const cloudflareR2 =  new CloudflareR2(
                        ENV.CLOUDFLARE_R2_BUCKET_NAME,
                        ENV.CLOUDFLARE_R2_KEY_ID,
                        ENV.CLOUDFLARE_R2_KEY_SECRET,
                        ENV.CLOUDFLARE_R2_ENDPOINT)

export { cloudflareR2 };





// interface UploadUrlRequest {
//   fileName: string;
//   fileSize: number;
//   mimeType: string;
//   contentType: 'video' | 'audio' | 'document' | 'image';
// }

// interface SignedUploadUrl {
//     mediaId: string;
//     fileName: string;
//     uploadUrl: string;
//     authorizationToken: string;
//     mediaPath: string;
//     cdnUrl: string;
// }


// class B2Service {
//   private b2: B2;
//   private bucketId: string;
//   private bucketName: string;
//   private authorized = false;

//   constructor() {
//     this.b2 = new B2({
//       applicationKeyId: ENV.OBJECT_STORAGE_KEY_ID,
//       applicationKey: ENV.OBJECT_STORAGE_KEY_SECRET,
//     });
//     this.bucketId = ENV.OBJECT_STORAGE_BUCKET_ID;
//     this.bucketName = ENV.OBJECT_STORAGE_BUCKET_NAME;
//   }

//   async authorize() {
//     if (!this.authorized) {
//       await this.b2.authorize();
//       this.authorized = true;
//     }
//   }

//   /**
//    * Generate signed upload URL for direct B2 upload
//    */
//   async generateSignedUploadUrl(
//     courseId: string | undefined,
//     file: UploadUrlRequest,
//     isThumbnail: boolean = false 
//   ): Promise<SignedUploadUrl> {
//     await this.authorize();

//     // Generate unique media ID
//     const mediaId = `media_${crypto.randomUUID()}`;

//     // For thumbnails, use thumbnails/media_xxx.jpg if no courseId, else thumbnails/courses/courseId/media_xxx.jpg
//     let mediaPath;
//     const fileExtension = this.getFileExtension(file.fileName);
//     if (isThumbnail) {
//       if (courseId) {
//         mediaPath = `thumbnails/${mediaId}${fileExtension}`;
//       } else {
//         mediaPath = `thumbnails/${mediaId}${fileExtension}`;
//       }
//     } else {
//       const folder = this.getFolder(file.contentType);
//       mediaPath = courseId
//         ? `courses/${courseId}/${folder}/${mediaId}${fileExtension}`
//         : `courses/${folder}/${mediaId}${fileExtension}`;
//     }

//     // Debug logging for B2 upload URL request
//     console.log('[B2] Requesting upload URL for bucket:', this.bucketId, 'mediaPath:', mediaPath);
//     const response = await this.b2.getUploadUrl({
//       bucketId: this.bucketId,
//     });
//     console.log('[B2] Received upload URL:', response.data.uploadUrl);

//     // Generate CDN URL
//     const cdnUrl = this.getCdnUrl(mediaPath);

//     return {
//       mediaId,
//       fileName: file.fileName,
//       uploadUrl: response.data.uploadUrl,
//       authorizationToken: response.data.authorizationToken,
//       mediaPath,
//       cdnUrl,
//     };
//   }

//   /**
//    * Verify file exists in B2
//    */
//   async verifyFileExists(mediaPath: string): Promise<boolean> {
//     try {
//       await this.authorize();
//       const response = await this.b2.listFileNames({
//         bucketId: this.bucketId,
//         startFileName: '',
//         prefix: mediaPath,
//         delimiter: '',
//         maxFileCount: 1,
//       });
//       return response.data.files.length > 0;
//     } catch (error) {
//       console.error('Error verifying file:', error);
//       return false;
//     }
//   }

//   /**
//    * Get public CDN URL for a file
//    */
//   getCdnUrl(mediaPath: string): string {
//     return `${ENV.MEDIA_CDN_BASE_URL}/${mediaPath}`;
//   }

//   /**
//    * Delete file from B2
//    */
//   async deleteFile(mediaPath: string): Promise<boolean> {
//     try {
//       await this.authorize();

//       // Get file info
//       const fileList = await this.b2.listFileNames({
//         bucketId: this.bucketId,
//         startFileName: '',
//         prefix: mediaPath,
//         delimiter: '',
//         maxFileCount: 1,
//       });

//       if (fileList.data.files.length === 0) {
//         return false;
//       }

//       const file = fileList.data.files[0];

//       // Delete file
//       await this.b2.deleteFileVersion({
//         fileId: file.fileId,
//         fileName: file.fileName,
//       });

//       return true;
//     } catch (error) {
//       console.error('Error deleting file:', error);
//       return false;
//     }
//   }

//   private getFolder(contentType: string): string {
//     switch (contentType) {
//       case 'video':
//         return 'videos';
//       case 'audio':
//         return 'audio';
//       case 'document':
//         return 'documents';
//       case 'image':
//         return 'images';
//       default:
//         return 'files';
//     }
//   }

//   private getFileExtension(fileName: string): string {
//     const match = fileName.match(/\.[^.]+$/);
//     return match ? match[0] : '';
//   }
// }

// export default new B2Service();