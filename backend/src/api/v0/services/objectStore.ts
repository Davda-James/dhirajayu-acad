// import B2 from 'backblaze-b2';
// import crypto from 'crypto';
import ENV from '@/shared/config/env';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';   
import { S3Client, PutObjectCommand, DeleteObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
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
    async checkFileExists(objectKey: string): Promise<boolean> {
        try {
            const command = new HeadObjectCommand({
                Bucket: this.bucketName,
                Key: objectKey,
            });
            await this.client.send(command);
            return true;
        } catch(error) {
            throw new Error(`Error checking file existence: ${error}`);
        }
    }
}

const cloudflareR2 =  new CloudflareR2(
                        ENV.CLOUDFLARE_R2_BUCKET_NAME,
                        ENV.CLOUDFLARE_R2_KEY_ID,
                        ENV.CLOUDFLARE_R2_KEY_SECRET,
                        ENV.CLOUDFLARE_R2_ENDPOINT)

export { cloudflareR2 };