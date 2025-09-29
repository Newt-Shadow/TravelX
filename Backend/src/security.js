import crypto from "crypto";
import { USER_SALT } from "./config.js";

export function deriveAnonUserId(rawAnonToken) {
  if (!rawAnonToken || typeof rawAnonToken !== "string") {
    throw new Error("Invalid anon token");
  }
  const h = crypto.createHmac("sha256", USER_SALT);
  h.update(rawAnonToken);
  return h.digest("hex");
}
