import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import ENV from '@/shared/config/env';


const adapter = new PrismaPg({ connectionString: ENV.DATABASE_URL })
const prisma = new PrismaClient({ adapter })

export default prisma;

