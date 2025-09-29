import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

export async function saveTripsBulk(trips) {
  return prisma.trip.createMany({
    data: trips,
    skipDuplicates: true
  });
}
