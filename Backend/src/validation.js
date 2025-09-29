import { z } from "zod";

export const flutterTripSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().min(8),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
  duration: z.number().int().nonnegative(),
  distance: z.number().optional(),
  mode: z.string().optional(),
  path: z.array(
    z.object({
      lat: z.number(),
      lng: z.number(),
      alt: z.number().optional(),
      timestamp: z.string().datetime()
    })
  ),
  meta: z.object({}).optional()
});
