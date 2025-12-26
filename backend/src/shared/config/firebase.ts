import admin from 'firebase-admin';
import ENV from '@/shared/config/env';
    
if (!admin.apps.length){
    admin.initializeApp({
        credential: admin.credential.cert(ENV.FIREBASE_SERVICE_ACCOUNT_KEY)
    })
}
export const firebaseAdmin = admin;

