import express from "express";
import { execSync } from "child_process";

const app = express();
app.use(express.json());

const API_KEY = process.env.API_KEY ?? "change-me-to-a-secret";
const DB_PATH = process.env.DB_PATH ?? "/home/ubuntu/services/fitness-services/data/fitness.db";
const PORT = Number(process.env.PORT ?? 3000);

function runSQL(sql: string): void {
  execSync(`sqlite3 "${DB_PATH}"`, { input: `.bail on\n${sql}\n` });
}

// Safe value escaping for SQLite
function esc(val: unknown): string {
  if (val === null || val === undefined) return "NULL";
  if (typeof val === "number") return String(val);
  return `'${String(val).replace(/'/g, "''")}'`;
}

// Create tables on startup
runSQL(`
CREATE TABLE IF NOT EXISTS running_workouts (
  id                    TEXT PRIMARY KEY,
  workout_type          TEXT NOT NULL,
  started_at            TEXT NOT NULL,
  ended_at              TEXT NOT NULL,
  duration_seconds      INTEGER NOT NULL,
  distance_meters       REAL,
  avg_heart_rate_bpm    REAL,
  max_heart_rate_bpm    REAL,
  calories_kcal         REAL,
  elevation_gain_meters REAL,
  avg_speed_mps         REAL,
  step_count            INTEGER,
  source                TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS health_measurements (
  id          TEXT PRIMARY KEY,
  type        TEXT NOT NULL,
  measured_at TEXT NOT NULL,
  value       REAL NOT NULL,
  unit        TEXT NOT NULL,
  source      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_running_workouts_started_at ON running_workouts (started_at);
CREATE INDEX IF NOT EXISTS idx_health_measurements_type_date ON health_measurements (type, measured_at);
`);

console.log(`health-sync receiver running on port ${PORT}`);

function requireApiKey(req: express.Request, res: express.Response, next: express.NextFunction) {
  if (req.headers["x-api-key"] !== API_KEY) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }
  next();
}

app.post("/workouts", requireApiKey, (req, res) => {
  const b = req.body;
  try {
    runSQL(`INSERT OR REPLACE INTO running_workouts
      (id, workout_type, started_at, ended_at, duration_seconds, distance_meters,
       avg_heart_rate_bpm, max_heart_rate_bpm, calories_kcal, elevation_gain_meters,
       avg_speed_mps, step_count, source)
      VALUES (${esc(b.id)}, ${esc(b.workout_type)}, ${esc(b.started_at)}, ${esc(b.ended_at)},
              ${esc(b.duration_seconds)}, ${esc(b.distance_meters)},
              ${esc(b.avg_heart_rate_bpm)}, ${esc(b.max_heart_rate_bpm)}, ${esc(b.calories_kcal)},
              ${esc(b.elevation_gain_meters)}, ${esc(b.avg_speed_mps)}, ${esc(b.step_count)},
              ${esc(b.source)});`);
    res.status(201).json({ ok: true });
  } catch (err) {
    console.error("Failed to insert workout:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.post("/measurements", requireApiKey, (req, res) => {
  const b = req.body;
  try {
    runSQL(`INSERT OR REPLACE INTO health_measurements
      (id, type, measured_at, value, unit, source)
      VALUES (${esc(b.id)}, ${esc(b.type)}, ${esc(b.measured_at)}, ${esc(b.value)}, ${esc(b.unit)}, ${esc(b.source)});`);
    res.status(201).json({ ok: true });
  } catch (err) {
    console.error("Failed to insert measurement:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(PORT);
