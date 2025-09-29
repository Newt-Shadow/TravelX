import mongoose from "mongoose";

const TripSchema = new mongoose.Schema({
  tripClientId: { type: String, required: true, unique: true, index: true },
  userId: { type: String, required: true, index: true },
  startTime: Date,
  endTime: Date,
  duration: Number,
  distance: Number,
  mode: String,
  path: [{ lat: Number, lng: Number, alt: Number, timestamp: Date }],
  meta: { type: Object }
}, { timestamps: true });

TripSchema.index({ tripClientId: 1 }, { unique: true });

export const TripMongo = mongoose.model("Trip", TripSchema);

export async function connectMongo(uri) {
  await mongoose.connect(uri);
  console.log("✅ MongoDB connected");
}
