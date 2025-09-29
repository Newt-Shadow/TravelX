// src/index.js
import { app } from "./server.js";
import { connectMongo } from "./mongo.js";
import { worker, tripQueue } from './queue.js'; // Import the worker and queue
import { PORT, MONGO_URL } from "./config.js";
import logger from "./logger.js";

// Declare server outside main so it's accessible by the shutdown handler
let server;

async function main() {
  await connectMongo(MONGO_URL);

  // Assign the server instance here
  server = app.listen(PORT, "0.0.0.0", () =>
    logger.info(`🚀 Server running on all network interfaces at http://0.0.0.0:${PORT}`)
  );
}

const gracefulShutdown = async (signal) => {
  logger.info(`Received ${signal}, shutting down gracefully...`);

  // 1. Stop the server from accepting new requests
  server.close(async () => {
    logger.info('HTTP server closed.');

    // 2. Close the queue and worker
    await worker.close();
    await tripQueue.close();
    logger.info('BullMQ worker and queue closed.');

    // 3. Close database connections (if needed)
    // You might add mongoose.disconnect() here if necessary

    process.exit(0);
  });
};

// Listen for shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Run the main application
main().catch(err => {
  logger.error(err);
  process.exit(1);
});