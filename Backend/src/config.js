import dotenv from "dotenv";
dotenv.config();

export const PORT = process.env.PORT || 5000;
export const NODE_ENV = process.env.NODE_ENV || "development";
export const DATABASE_URL = process.env.DATABASE_URL;
export const MONGO_URL = process.env.MONGO_URL;
export const REDIS_URL = process.env.REDIS_URL;
export const USER_SALT = process.env.USER_SALT;

export const BATCH_SIZE = parseInt(process.env.BATCH_SIZE) || 200;
export const BATCH_TIMEOUT_MS = parseInt(process.env.BATCH_TIMEOUT_MS) || 1000;
export const MAX_CONCURRENCY = parseInt(process.env.MAX_CONCURRENCY) || 4;
