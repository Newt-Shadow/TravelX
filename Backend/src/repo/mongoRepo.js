import { TripMongo } from "../mongo.js";

export async function saveTripsMongoBulk(trips) {
  try {
    const res = await TripMongo.insertMany(trips, { ordered: false });
    return res.length;
  } catch (e) {
    if (e && e.insertedCount) return e.insertedCount;
    throw e;
  }
}
