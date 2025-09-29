-- CreateTable
CREATE TABLE "Trip" (
    "id" TEXT NOT NULL,
    "tripClientId" TEXT NOT NULL,
    "anonUser" TEXT NOT NULL,
    "startTime" TIMESTAMP(3) NOT NULL,
    "endTime" TIMESTAMP(3) NOT NULL,
    "duration" INTEGER NOT NULL,
    "distance" DOUBLE PRECISION,
    "mode" TEXT,
    "path" JSONB NOT NULL,
    "meta" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Trip_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Trip_tripClientId_key" ON "Trip"("tripClientId");
