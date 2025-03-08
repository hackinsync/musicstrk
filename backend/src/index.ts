
import "dotenv/config";
import path from "path";
import mongoose from "mongoose";
import express, { urlencoded, json } from 'express';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import { fileURLToPath } from "url";

import AuthRoutes from './routes/v1/auth.js';
import UserRoutes from "routes/v1/user.js";

// Load environment variables
process.loadEnvFile(".env");
console.log(process.env.NODE_ENV);


const __dirname = path.dirname(fileURLToPath(import.meta.url));
const testsDir = path.resolve(__dirname + "/../tests");
console.log(testsDir);



const app = express();

// setup neccesary root-level middlewares & parsers
app.use(cors());
app.use(urlencoded({ extended: true }));
app.use(json());
app.use(cookieParser());



const PORT = process.env.PORT || 8080;
const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
    throw ("Mongo URI not found in .env file");
}

if (!process.env.JWT_SECRET) {
    throw ("JWT Secret not found in .env file");
}


// start test page if in dev mode
if (process.env.NODE_ENV === 'development') {
    app.use(express.static(testsDir));
    app.get('/mode', (req, res) => {
        res.send('Debug mode');
    });
}


mongoose
    .connect(MONGODB_URI)
    .then(() => console.log("MongoDB Connected"))
    .catch((err) => console.error("MongoDB Connection Error:", err));


// declare routes below
app.use('/api/v1/auth', AuthRoutes);
app.use('/api/v1/user', UserRoutes);


app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
