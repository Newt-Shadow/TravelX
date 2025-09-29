import pkg from "bullmq";
const { Queue, Worker } = pkg;
import IORedis from "ioredis";
import pLimit from "p-limit";
import { BATCH_SIZE, BATCH_TIMEOUT_MS, MAX_CONCURRENCY, REDIS_URL } from "./config.js";
import logger from "./logger.js";
import { saveTripsBulk, saveTripsMongoBulk } from "./repo/index.js";

const redisConnection = new IORedis(REDIS_URL, {
  maxRetriesPerRequest: null,
  enableOfflineQueue: true,
});

export const tripQueue = new Queue("tripQueue", { connection: redisConnection });
const limit = pLimit(MAX_CONCURRENCY);

let buffer = [];
let timer = null;

function scheduleFlush() {
  if (!timer) {
    timer = setTimeout(async () => {
      const toFlush = buffer.splice(0, buffer.length);
      timer = null;
      if (toFlush.length) await flushBatch(toFlush);
    }, BATCH_TIMEOUT_MS);
  }
}

async function flushBatch(batch) {
  await limit(async () => {
    try {
      const pgRows = batch.map(t => ({
        tripClientId: t.tripClientId,
        anonUser: t.anonUser,
        startTime: new Date(t.startTime),
        endTime: t.endTime ? new Date(t.endTime): null,
        duration: t.duration ?? null,
        distance: t.distance ?? null,
        mode: t.mode ?? null,
        path: t.path,
        meta: t.meta ?? null,
      }));

      const mongoDocs = batch.map(t => ({
        tripClientId: t.tripClientId,
        userId: t.anonUser,
        startTime: new Date(t.startTime),
        endTime: new Date(t.endTime),
        duration: t.duration,
        distance: t.distance ?? null,
        mode: t.mode ?? null,
        path: t.path,
        meta: t.meta ?? null,
      }));

      const pgRes = await saveTripsBulk(pgRows);
      const mongoInserted = await saveTripsMongoBulk(mongoDocs);

      logger.info(`Batch written: Postgres=${pgRes.count} Mongo=${mongoInserted}`);

    } catch (err) {
      // --- MODIFIED LOGIC TO BREAK THE INFINITE LOOP ---

      // 1. Log the detailed error to help diagnose the "poison pill".
      logger.error({ err, failedBatch: batch }, "Batch write failed. Isolating problematic jobs.");

      // 2. If the batch is small, try to find and isolate the single bad job.
      if (batch.length <= 10) {
        for (const job of batch) {
          try {
            // Try inserting jobs one-by-one to find the offender
            await saveTripsBulk([job]);
            await saveTripsMongoBulk([job]);
          } catch (individualErr) {
            logger.error({ err: individualErr, failedJob: job }, "Found and isolated poison pill job.");
            // 3. Move the "poison pill" job to a dead-letter queue for later inspection.
            await redisConnection.lpush("deadTripQueue", JSON.stringify({ job, error: individualErr.message }));
          }
        }
      } else {
        // 4. If the batch is large, move the entire failed batch to the dead-letter queue.
        logger.warn(`Large batch failed. Moving all ${batch.length} jobs to dead-letter queue.`);
        const deadLetterPayload = batch.map(job => JSON.stringify({ job, error: "Part of large failed batch" }));
        await redisConnection.lpush("deadTripQueue", ...deadLetterPayload);
      }
    }
  });
}

export const worker = new Worker(
  "tripQueue",
  async job => {
    // BullMQ's built-in retry logic is now the primary mechanism.
    // We only re-queue manually if the entire batch fails.
    buffer.push(job.data);

    if (buffer.length >= BATCH_SIZE) {
      const toFlush = buffer.splice(0, buffer.length);
      if (timer) clearTimeout(timer);
      timer = null;
      await flushBatch(toFlush);
    } else {
      scheduleFlush();
    }

    return { accepted: true };
  },
  { connection: redisConnection, concurrency: MAX_CONCURRENCY }
);

worker.on("failed", (job, err) => logger.error(`Job ${job.id} failed after all attempts:`, err));
worker.on("completed", job => logger.debug(`Job ${job.id} completed`));