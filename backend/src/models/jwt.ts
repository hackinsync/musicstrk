import mongoose, { Schema, Document } from "mongoose";

export interface TokenDocument extends Document {
  userId: mongoose.Types.ObjectId;
  token: string;
  createdAt: Date;
}

const TokenSchema = new Schema<TokenDocument>({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  token: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
});

export default mongoose.model<TokenDocument>("JWToken", TokenSchema);
