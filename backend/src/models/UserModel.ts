import { Schema, model } from "mongoose";
import { User, Role } from "../types";


const UserSchema = new Schema<User>({
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    walletAddress: { type: String, required: true, unique: true },
    pubKey: { type: String, required: true },
    role: { type: String, enum: Object.values(Role), default: Role.USER },
    createdAt: { type: Date, default: Date.now },
});

const UserModel = model<User>("User", UserSchema);
export default UserModel


export const createUser = async (user: User) => {
    return await UserModel.create(user);
}