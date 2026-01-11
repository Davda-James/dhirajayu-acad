import express from 'express';
import ENV from '@/shared/config/env';
import cors from 'cors';
import '@/shared/config/firebase';

import userRouter from '@v0/routes/user'; 
import courseRouter from '@v0/routes/course';
import moduleRouter from '@v0/routes/module';
import folderRouter from '@v0/routes/folder';
import mediaAssetRouter from '@v0/routes/mediaAsset';
import mediaUsageRouter from '@v0/routes/mediaUsage';
import testRouter from '@v0/routes/test';
import { verifyToken } from '@/api/v0/middlewares/auth';

const app = express();

app.use(express.json())
app.use(express.urlencoded({ extended: true }))
app.use(cors());

app.get("/status", (_, res) => {
    res.status(200).send({ status: "OK" });
});


app.use('/api/v0/users', verifyToken, userRouter);
app.use('/api/v0/courses', verifyToken, courseRouter); 
app.use('/api/v0/modules', verifyToken, moduleRouter);
app.use('/api/v0/folders', verifyToken, folderRouter); 
app.use('/api/v0/media-assets', verifyToken, mediaAssetRouter);
app.use('/api/v0/media-usages', verifyToken, mediaUsageRouter);
app.use('/api/v0/tests', verifyToken,  testRouter);

app.listen(ENV.PORT, () => {
    console.log(`Server is listening on port ${ENV.PORT}`)
})

export default app;