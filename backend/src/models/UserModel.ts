import { Schema, model } from "mongoose";
import { User, Role } from "../types";
import { BigNumberish } from "starknet";


const UserSchema = new Schema<User>({
    name: { type: String, required: false },
    email: { type: String, required: false, unique:true, default: null, sparse:true },
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

export const findUserByaddress = async (address: BigNumberish) => {
    return await UserModel.findOne({ walletAddress: address.toString() });
  };
  