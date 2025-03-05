
import "dotenv/config";
import express, { urlencoded, json } from 'express';
import cors from 'cors';
import routes from './routes/v1/auth.js';
import path from "path";
import { fileURLToPath } from "url";

// Load environment variables
process.loadEnvFile(".env");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const testsDir = path.resolve(__dirname + "/../tests");


console.log(process.env.NODE_ENV);

const app = express();
const PORT = process.env.PORT || 8080;

if (process.env.NODE_ENV === "development") app.use(express.static(testsDir));

console.log(testsDir);


app.use(cors());
app.use(urlencoded({ extended: true }));
app.use(json());


// start test page if in dev mode
if (process.env.NODE_ENV === 'development') {
    app.get('/', (req, res) => {
        res.send('Hello World');
    });
}


app.use('/api/v1', routes);

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
