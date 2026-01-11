import dotenv from 'dotenv'
dotenv.config()

const ENV = {
    PORT: process.env.PORT!,
    NODE_ENV: process.env.NODE_ENV || 'development',
    DATABASE_URL: process.env.DATABASE_URL!,
    FIREBASE_SERVICE_ACCOUNT_KEY: JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY!),    
    // OBJECT_STORAGE_BUCKET_ID: process.env.OBJECT_STORAGE_BUCKET_ID!,
    // OBJECT_STORAGE_KEY_ID: process.env.OBJECT_STORAGE_BUCKET_KEY_ID!,
    // OBJECT_STORAGE_KEY_SECRET: process.env.OBJECT_STORAGE_BUCKET_KEY_SECRET!,
    CLOUDFLARE_R2_KEY_ID: process.env.CLOUDFLARE_R2_KEY_ID!,
    CLOUDFLARE_R2_KEY_SECRET: process.env.CLOUDFLARE_R2_KEY_SECRET!,
    CLOUDFLARE_R2_TOKEN_VALUE: process.env.CLOUDFLARE_R2_TOKEN_VALUE!,
    CLOUDFLARE_R2_BUCKET_NAME: process.env.CLOUDFLARE_R2_BUCKET_NAME!,
    CLOUDFLARE_R2_ENDPOINT: process.env.CLOUDFLARE_R2_ENDPOINT!,
    MEDIA_WORKER_TOKEN_TTL_SECONDS: parseInt(process.env.MEDIA_WORKER_TOKEN_TTL_SECONDS!) || 86400,
    JWT_SECRET: process.env.JWT_SECRET!,
    MEDIA_CDN_BASE_URL: process.env.MEDIA_CDN_BASE_URL!,
    WORKER_BASE_URL: process.env.WORKER_BASE_URL!,
    RAZORPAY_KEY_ID: process.env.NODE_ENV === 'production' ? process.env.RAZORPAY_PROD_ID! : process.env.RAZORPAY_TEST_ID!,
    RAZORPAY_KEY_SECRET: process.env.NODE_ENV === 'production' ? process.env.RAZORPAY_PROD_SECRET! : process.env.RAZORPAY_TEST_SECRET!,
    ADMIN_ACCOUNT_MAIL: process.env.ADMIN_ACCOUNT_MAIL!
}


export default ENV;