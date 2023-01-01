import express, { Express, Request, Response} from 'express';
import { Pool } from 'pg';

const app: Express = express();
app.use(express.json());

const port = process.env.PORT;
const dbHost = process.env.DB_HOST;
const dbUser = process.env.DB_USER;
const dbPassword = process.env.DB_PASSWORD;

const pool = new Pool({
    host: dbHost,
    user: dbUser,
    password: dbPassword
});

app.get('/health', (req: Request, res: Response) => {
    res.send('OK');
});

app.get('/movies', async (req: Request, res: Response) => {
    const { rows } = await pool.query("SELECT * FROM movies");
    res.send({
        movies: rows
    });
});

app.post('/movies', async (req: Request, res: Response) => {
    const entry = req.body;
    const { rows } = await pool.query("INSERT INTO movies (title, director) VALUES ($1, $2)",
        [entry.title, entry.director]);
    res.send(rows[0]);
});

app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
});