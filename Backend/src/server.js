import express from "express";
import helmet from "helmet";
import cors from "cors";
import bodyParser from "body-parser";
import { PrismaClient } from "@prisma/client"; // Import Prisma Client
import logger from "./logger.js";
import { deriveAnonUserId } from "./security.js";
import { tripQueue } from "./queue.js";

// Initialize Prisma Client
const prisma = new PrismaClient();

export const app = express();
app.use(helmet());
app.use(cors({ origin: "*" }));
app.use(bodyParser.json({ limit: "5mb" }));

// ✅ Utility: Normalize whatever user identifier we receive
function normalizeUserIdentifier(raw) {
  if (!raw) return null;

  if (typeof raw === "string") return raw.trim();
  if (typeof raw === "number") return String(raw);

  if (typeof raw === "object") {
    // Try common keys
    if (raw.id) return String(raw.id);
    if (raw.userId) return String(raw.userId);
    if (raw.hash) return String(raw.hash);

    // Fallback: stringify whole object
    return JSON.stringify(raw);
  }

  return null;
}

app.post("/api/trips", async (req, res) => {
  try {
    const trip = req.body;

    if (!trip.id || !trip.createdAt) {
      logger.warn(
        { tripData: trip },
        "Received trip with missing ID or createdAt. Rejecting."
      );
      return res
        .status(400)
        .json({ error: "Invalid trip data: id and createdAt are required." });
    }

    // ✅ Normalize userId before hashing
    const rawUserId = normalizeUserIdentifier(trip.anonUserId ?? trip.userId);
    const anonUser = deriveAnonUserId(rawUserId ?? "guest");

    // ✅ Extract times from first/last segment
    const startTime =
      trip.segments?.length > 0 ? trip.segments[0].start : trip.createdAt;
    const endTime =
      trip.segments?.length > 0
        ? trip.segments[trip.segments.length - 1].end || null
        : null;

    // ✅ Flatten GPS points into a "path"
    const path = (trip.segments || []).flatMap((seg) =>
      (seg.gps || []).map((g) => ({
        lat: g.lat,
        lng: g.lng,
        ts: g.ts || seg.start,
      }))
    );

    // ✅ Build backend trip
    const backendTrip = {
      tripClientId: trip.id,
      anonUser,
      startTime,
      endTime,
      duration:
        startTime && endTime
          ? Math.floor(
              (new Date(endTime).getTime() - new Date(startTime).getTime()) /
                1000
            )
          : null,
      distance: trip.distance ?? null, // TODO: compute from path if needed
      mode: trip.segments?.[0]?.mode || null,
      path,
      meta: {
        companions: trip.companions || [],
      },
    };

    // ✅ Push into queue
    await tripQueue.add("saveTrip", backendTrip, {
      removeOnComplete: true,
      removeOnFail: { count: 100 },
      attempts: 5,
      backoff: { type: "exponential", delay: 500 },
    });

    res.status(202).json({ message: "Trip queued for saving" });
  } catch (err) {
    logger.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

// ⭐ NEW: GET endpoint to fetch past trips for a user
// ⭐ NEW: GET endpoint to fetch past trips for a user
app.get("/api/trips/:anonUser", async (req, res) => {
  try {
    const rawUserId = req.params.anonUser; // Get the raw ID from the URL
    if (!rawUserId) {
      return res.status(400).json({ error: "User identifier is required." });
    }

    // ✨ FIX: Apply the same transformation used when saving a trip
    const anonUser = deriveAnonUserId(rawUserId);

    const trips = await prisma.trip.findMany({
      where: { anonUser }, // Now you are querying with the correct, transformed ID
      orderBy: { startTime: "desc" },
      take: 50,
    });

    res.status(200).json(trips);
  } catch (err) {
    logger.error(err, `Failed to fetch trips for user ${req.params.anonUser}`);
    res.status(500).json({ error: "Server error while fetching trips." });
  }
});

app.get("/health", (_, res) => res.json({ status: "ok" }));