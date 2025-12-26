export interface ObjectStore {
    getPreSignedUploadUrl(fileKey: string, expiresInSeconds: number): Promise<string>;
    deleteMediaFile(fileKey: string): Promise<boolean>;
}
