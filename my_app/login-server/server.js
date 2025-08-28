// ---------- Top-level setup ----------
require("dotenv").config();

const express = require("express");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const cors = require("cors");
const { z } = require("zod");
const OpenAI = require("openai");
const {
  parseISO,
  subDays,
  isSameDay,
  formatISO,
  isWithinInterval,
  eachDayOfInterval,
} = require('date-fns');


const db = require("./db");

// Secrets & config
const SECRET = process.env.JWT_SECRET || "dev-only-change-me";
const PORT = process.env.PORT || 3000;

// OpenAI client
const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// ---------- App & middleware ----------
const app = express();
app.use(express.json());
app.use(cors());

// ---------- Auth middleware ----------
function authenticateToken(req, res, next) {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];
  if (!token) return res.sendStatus(401);

  jwt.verify(token, SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.userId = user.userId;
    next();
  });
}

// ---------- Predict (OpenAI) ----------
const PredictBody = z.object({
  habitName: z.string().min(1),
  currentStreak: z.number().int().nonnegative(),
  reflection: z.string().default(''),
  features: z.object({
    last7Count: z.number().int().min(0).max(7).optional(),
    last30Count: z.number().int().min(0).max(31).optional(),
    weeklyFrequencyTarget: z.number().int().min(1).max(7).optional(),
    last7Days: z.array(z.boolean()).min(1).max(7).optional(),
    timeOfDay: z.string().optional(),
    sleepHoursAvg: z.number().optional(),
    stressLevel: z.number().min(1).max(10).optional(),
  }).partial().default({})
});





app.post("/predict", async (req, res) => {
  const parsed = PredictBody.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const { habitName, currentStreak, reflection, features } = parsed.data;

  const jsonSchema = {
    name: "HabitPrediction",
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        successProbability: { type: "integer", minimum: 0, maximum: 100 },
        recommendation: { type: "string" },
        riskFactors: { type: "array", items: { type: "string" } },
        rationale: { type: "string" },
      },
      required: ["successProbability", "recommendation", "riskFactors", "rationale"],
    },
    strict: true,
  };

  const system = [
    "You predict the 7-day completion likelihood for a single habit.",
    "Calibrate probability using streaks and recent history.",
    "Return JSON only that matches the provided schema.",
  ].join(" ");

  const user = `
Habit: ${habitName}
Current streak (days): ${currentStreak}
User reflection: ${reflection}
Features: ${JSON.stringify(features)}
Goal: Probability of completing this habit over the next 7 days.
Return JSON only.`.trim();

  try {
    const resp = await client.responses.create({
      model: "gpt-4.1-mini",
      input: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
      response_format: { type: "json_schema", json_schema: jsonSchema },
    });

    const data = resp.output_text
      ? JSON.parse(resp.output_text)
      : resp.output?.[0]?.content?.[0]?.text
      ? JSON.parse(resp.output[0].content[0].text)
      : null;

    if (!data) return res.status(500).json({ error: "No prediction returned" });
    return res.json(data);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "Prediction failed" });
  }
});


// ---------- Auth-related sample routes ----------
app.post("/register", async (req, res) => {
  const { username, password } = req.body;
  const hashedPassword = await bcrypt.hash(password, 10);
  db.run(
    "INSERT INTO users (username, password) VALUES (?, ?)",
    [username, hashedPassword],
    (err) => {
      if (err) return res.status(400).json({ error: "Username already exists" });
      res.json({ message: "User registered successfully" });
    }
  );
});

// ---------- Sleep (deduplicated) ----------
app.post("/sleep", (req, res) => {
  const { userId, date, hours } = req.body;
  if (!userId || !date || typeof hours !== "number") {
    return res.status(400).json({ error: "Missing or invalid data" });
  }
  db.run(
    "INSERT INTO sleep (user_id, date, hours) VALUES (?, ?, ?)",
    [userId, date, hours],
    function (err) {
      if (err) {
        console.error("DB error inserting sleep data:", err.message);
        return res.status(500).json({ error: "Failed to save sleep data" });
      }
      res.json({ message: "Sleep data saved successfully", id: this.lastID });
    }
  );
});

app.get("/sleep", (req, res) => {
  const { userId } = req.query;
  db.all(
    "SELECT date, hours FROM sleep WHERE user_id = ? ORDER BY date DESC",
    [userId],
    (err, rows) => {
      if (err) {
        console.error("DB error fetching sleep data:", err.message);
        return res.status(500).json({ error: "Failed to load sleep data" });
      }
      res.json(rows);
    }
  );
});

// ---------- Moods ----------
app.post("/moods", authenticateToken, (req, res) => {
  const { mood, date } = req.body;
  db.run(
    "INSERT INTO moods (user_id, mood, date) VALUES (?, ?, ?)",
    [req.userId, mood, date],
    function (err) {
      if (err) return res.status(500).json({ error: "Failed to save mood" });
      res.json({ message: "Mood saved successfully", id: this.lastID });
    }
  );
});

app.get("/moods", authenticateToken, (req, res) => {
  db.all(
    "SELECT mood, date FROM moods WHERE user_id = ? ORDER BY date ASC",
    [req.userId],
    (err, rows) => {
      if (err) return res.status(500).json({ error: "Failed to load moods" });
      res.json(rows);
    }
  );
});

// ---------- Analyze ----------
const analyzeMood = require("./openai");
app.post("/analyze", authenticateToken, async (req, res) => {
  const { note, goals } = req.body;
  try {
    const insight = await analyzeMood(note, goals);
    res.json({ insight });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to analyze mood" });
  }
});

// ---------- Goals ----------
app.get("/goals", authenticateToken, (req, res) => {
  db.get("SELECT goal_text FROM goals WHERE user_id = ?", [req.userId], (err, row) => {
    if (err) return res.status(500).json({ error: "Error fetching goals" });
    res.json({ goals: row?.goal_text ?? "" });
  });
});

// ---------- Journal (with mood/tags/gratitude) ----------
app.post("/journal", authenticateToken, (req, res) => {
  const { title, entry, timestamp, mood, tags, gratitude } = req.body;

  db.run(
    "INSERT INTO journals (user_id, title, entry, timestamp, mood, tags, gratitude) VALUES (?, ?, ?, ?, ?, ?, ?)",
    [
      req.userId,
      title,
      entry,
      timestamp,
      mood ?? null,
      JSON.stringify(tags ?? []),
      JSON.stringify(gratitude ?? []),
    ],
    function (err) {
      if (err) {
        console.error("DB error inserting journal:", err.message);
        return res.status(500).json({ error: "Failed to save entry" });
      }
      res.json({ message: "Entry saved", id: this.lastID });
    }
  );
});

app.get("/journal", authenticateToken, (req, res) => {
  db.all(
    "SELECT title, entry, timestamp, mood, tags, gratitude FROM journals WHERE user_id = ? ORDER BY timestamp DESC",
    [req.userId],
    (err, rows) => {
      if (err) {
        console.error("DB error:", err);
        return res.status(500).json({ error: "Failed to load journal entries" });
      }
      const parsed = rows.map((r) => ({
        ...r,
        tags: r.tags ? JSON.parse(r.tags) : [],
        gratitude: r.gratitude ? JSON.parse(r.gratitude) : [],
      }));
      res.json(parsed);
    }
  );
});

// ---------- Pillars ----------

app.post("/pillars/:pillarId/habits", authenticateToken, (req, res) => {
  const { pillarId } = req.params;
  const { title } = req.body;
  db.run(
    "INSERT INTO habits (user_id, pillar_id, title, completed, streak) VALUES (?, ?, ?, 0, 0)",
    [req.userId, pillarId, title],
    function (err) {
      if (err) return res.status(500).json({ error: "Failed to add habit" });
      res.json({ id: this.lastID });
    }
  );
});


app.get("/pillars", authenticateToken, (req, res) => {
  // fetch pillars
  db.all(
    "SELECT id, title, description, color, progress FROM pillars WHERE user_id = ? ORDER BY id DESC",
    [req.userId],
    (err, pillars) => {
      if (err) return res.status(500).json({ error: "Failed to load pillars" });

      if (pillars.length === 0) return res.json([]);

      // fetch habits for all pillars at once, then group
      const ids = pillars.map(p => p.id);
      const placeholders = ids.map(() => "?").join(",");
      db.all(
        `SELECT id, pillar_id, title, completed, streak
         FROM habits
         WHERE user_id = ? AND pillar_id IN (${placeholders})
         ORDER BY id DESC`,
        [req.userId, ...ids],
        (hErr, habits) => {
          if (hErr) return res.status(500).json({ error: "Failed to load habits" });

          const byPillar = {};
          for (const h of habits) {
            byPillar[h.pillar_id] = byPillar[h.pillar_id] || [];
            byPillar[h.pillar_id].push({
              id: h.id,
              title: h.title,
              completed: !!h.completed,
              streak: h.streak
            });
          }

          const result = pillars.map(p => ({
            id: p.id,
            title: p.title,
            description: p.description,
            color: p.color,        // 32-bit ARGB int
            progress: p.progress,  // 0..100
            habits: byPillar[p.id] || []
          }));

          res.json(result);
        }
      );
    }
  );
});

app.post("/pillars", authenticateToken, (req, res) => {
  const { title, description = "", color = 0xFF3B82F6, progress = 0 } = req.body;
  db.run(
    "INSERT INTO pillars (user_id, title, description, color, progress) VALUES (?, ?, ?, ?, ?)",
    [req.userId, title, description, color, progress],
    function (err) {
      if (err) return res.status(500).json({ error: "Failed to create pillar" });
      res.json({ id: this.lastID, title, description, color, progress, habits: [] });
    }
  );
});


app.patch("/habits/:habitId/toggle", authenticateToken, (req, res) => {
  const { habitId } = req.params;
  // toggle and update streak simply (example logic)
  db.get(
    "SELECT completed, streak FROM habits WHERE id = ? AND user_id = ?",
    [habitId, req.userId],
    (err, row) => {
      if (err || !row) return res.status(404).json({ error: "Habit not found" });
      const nextCompleted = row.completed ? 0 : 1;
      const nextStreak = nextCompleted ? row.streak + 1 : Math.max(0, row.streak - 1);
      db.run(
        "UPDATE habits SET completed = ?, streak = ? WHERE id = ? AND user_id = ?",
        [nextCompleted, nextStreak, habitId, req.userId],
        (uErr) => {
          if (uErr) return res.status(500).json({ error: "Failed to update habit" });
          res.json({ completed: !!nextCompleted, streak: nextStreak });
        }
      );
    }
  );
});


// ---------- Streaks (fix: import date-fns) ----------
app.get("/streaks", authenticateToken, (req, res) => {
  db.all(
    "SELECT date FROM moods WHERE user_id = ? ORDER BY date DESC",
    [req.userId],
    (err, rows) => {
      if (err) return res.status(500).json({ error: "Failed to load streaks" });

      const dates = rows.map((row) => parseISO(row.date));
      let streak = 0;
      let day = new Date(); // today

      // Count consecutive days with entries up to today
      while (true) {
        const match = dates.find((d) => isSameDay(d, day));
        if (match) {
          streak++;
          day = subDays(day, 1);
        } else {
          break;
        }
      }
      res.json({ streak });
    }
  );
});

app.post('/habit/complete', authenticateToken, (req, res) => {
  const { habitName, date } = req.body; // date = yyyy-mm-dd
  if (!habitName || !date) return res.status(400).json({ error: 'habitName and date required' });
  db.run(
    `INSERT OR IGNORE INTO habit_events (user_id, habit_name, date)
     VALUES (?, ?, ?)`,
    [req.userId, habitName, date],
    function (err) {
      if (err) return res.status(500).json({ error: 'Failed to log completion' });
      res.json({ ok: true });
    }
  );
});

app.post('/predict_from_history', authenticateToken, (req, res) => {
  const { habitName, weeklyFrequencyTarget = 5, reflection = '' } = req.body;
  if (!habitName) return res.status(400).json({ error: 'habitName required' });

  const today = new Date();
  const start7 = subDays(today, 6);     // inclusive window: 7 days
  const start30 = subDays(today, 29);   // inclusive window: 30 days
  const startStreak = subDays(today, 60); // window to compute streak

  db.all(
    `SELECT date FROM habit_events
     WHERE user_id = ? AND habit_name = ?
       AND date >= ?`,
    [req.userId, habitName, formatISO(start30, { representation: 'date' })],
    async (err, rows) => {
      if (err) return res.status(500).json({ error: 'DB error' });

      const dates = new Set(rows.map(r => r.date)); // yyyy-mm-dd

      // counts
      const last7Days = eachDayOfInterval({ start: start7, end: today })
        .map(d => dates.has(formatISO(d, { representation: 'date' })));
      const last30Days = eachDayOfInterval({ start: start30, end: today })
        .map(d => dates.has(formatISO(d, { representation: 'date' })));

      const last7Count = last7Days.filter(Boolean).length;
      const last30Count = last30Days.filter(Boolean).length;

      // streak (consecutive days including today)
      let day = today;
      let streak = 0;
      while (dates.has(formatISO(day, { representation: 'date' }))) {
        streak++;
        day = subDays(day, 1);
      }

      // Call your existing /predict logic inline (no second HTTP hop)
      try {
        const jsonSchema = {
          name: "HabitPrediction",
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              successProbability: { type: "integer", minimum: 0, maximum: 100 },
              recommendation: { type: "string" },
              riskFactors: { type: "array", items: { type: "string" } },
              rationale: { type: "string" },
            },
            required: ["successProbability", "recommendation", "riskFactors", "rationale"],
          },
          strict: true,
        };

        const system = `
You predict the next 7-day completion likelihood for a habit.
Use these signals:
- last7Count (recent momentum, strongest weight)
- last30Count (baseline adherence)
- streak (consistency)
- weeklyFrequencyTarget (difficulty)
If last7Count >= weeklyFrequencyTarget, probability should be high (80–95) unless month is very weak.
If last7Count is much lower than target, lower probability.
Return JSON only.
        `.trim();

        const userMsg = `
Habit: ${habitName}
Signals:
- last7Count=${last7Count} of 7
- last30Count=${last30Count} of 30
- currentStreak=${streak} days
- weeklyFrequencyTarget=${weeklyFrequencyTarget} / week
Reflection: ${reflection}
        `.trim();

        const resp = await client.responses.create({
          model: "gpt-4.1-mini",
          input: [
            { role: "system", content: system },
            { role: "user", content: userMsg },
          ],
          response_format: { type: "json_schema", json_schema: jsonSchema },
        });

        const data = resp.output_text
          ? JSON.parse(resp.output_text)
          : resp.output?.[0]?.content?.[0]?.text
          ? JSON.parse(resp.output[0].content[0].text)
          : null;

        if (!data) return res.status(500).json({ error: "No prediction returned" });

        // Optional: add transparently the computed signals for UI
        return res.json({
          ...data,
          signals: {
            last7Count,
            last30Count,
            currentStreak: streak,
            weeklyFrequencyTarget,
          },
        });
      } catch (e) {
        console.error(e);
        return res.status(500).json({ error: "Prediction failed" });
      }
    }
  );
});


app.get("/me/friend_code", authenticateToken, (req, res) => {
  db.get("SELECT friend_code FROM users WHERE id = ?", [req.userId], (err, row) => {
    if (err) return res.status(500).json({ error: "DB error" });
    res.json({ friendCode: row?.friend_code ?? "" });
  });
});

app.post("/friends/search", authenticateToken, (req, res) => {
  const { code } = req.body;
  if (!code) return res.status(400).json({ error: "code required" });
  db.get("SELECT id, username, friend_code FROM users WHERE friend_code = ?", [code], (err, row) => {
    if (err) return res.status(500).json({ error: "DB error" });
    if (!row) return res.status(404).json({ error: "Not found" });
    if (row.id === req.userId) return res.status(400).json({ error: "Cannot friend yourself" });
    res.json(row);
  });
});

app.post("/friends/request", authenticateToken, (req, res) => {
  const { friendId } = req.body;
  if (!friendId) return res.status(400).json({ error: "friendId required" });
  const { a, b } = pair(req.userId, friendId);

  db.run(
    `INSERT OR IGNORE INTO friendships (user_low, user_high, requester_id, status)
     VALUES (?, ?, ?, 'pending')`,
    [a, b, req.userId],
    function (err) {
      if (err) return res.status(500).json({ error: "DB error" });
      if (this.changes === 0) {
        // already exists → update if previously declined
        db.run(
          `UPDATE friendships SET requester_id = ?, status = 'pending'
           WHERE user_low = ? AND user_high = ? AND status = 'declined'`,
          [req.userId, a, b],
          function (uErr) {
            if (uErr) return res.status(500).json({ error: "DB error" });
            return res.json({ ok: true, status: "pending" });
          }
        );
      } else {
        return res.json({ ok: true, status: "pending" });
      }
    }
  );
});

app.post("/friends/accept", authenticateToken, (req, res) => {
  const { friendId } = req.body;
  if (!friendId) return res.status(400).json({ error: "friendId required" });
  const { a, b } = pair(req.userId, friendId);

  // Only the non-requester should accept
  db.run(
    `UPDATE friendships
     SET status = 'accepted'
     WHERE user_low = ? AND user_high = ? AND status = 'pending'
       AND requester_id != ?`,
    [a, b, req.userId],
    function (err) {
      if (err) return res.status(500).json({ error: "DB error" });
      if (this.changes === 0) return res.status(400).json({ error: "No pending request to accept" });
      res.json({ ok: true });
    }
  );
});

app.post("/friends/decline", authenticateToken, (req, res) => {
  const { friendId } = req.body;
  if (!friendId) return res.status(400).json({ error: "friendId required" });
  const { a, b } = pair(req.userId, friendId);
  db.run(
    `UPDATE friendships
     SET status = 'declined'
     WHERE user_low = ? AND user_high = ? AND status = 'pending'`,
    [a, b],
    function (err) {
      if (err) return res.status(500).json({ error: "DB error" });
      res.json({ ok: true });
    }
  );
});

// Accepted friends
app.get("/friends", authenticateToken, (req, res) => {
  db.all(
    `
    SELECT u.id, u.username, u.friend_code
    FROM friendships f
    JOIN users u
      ON (CASE WHEN f.user_low = ? THEN f.user_high ELSE f.user_low END) = u.id
    WHERE (f.user_low = ? OR f.user_high = ?) AND f.status = 'accepted'
    ORDER BY u.username
    `,
    [req.userId, req.userId, req.userId],
    (err, rows) => {
      if (err) return res.status(500).json({ error: "DB error" });
      res.json(rows);
    }
  );
});

// Incoming pending requests (you need to accept)
app.get("/friends/requests", authenticateToken, (req, res) => {
  db.all(
    `
    SELECT u.id, u.username, u.friend_code
    FROM friendships f
    JOIN users u
      ON u.id = f.requester_id
    WHERE (f.user_low = ? OR f.user_high = ?)
      AND f.status = 'pending'
      AND f.requester_id != ?
    `,
    [req.userId, req.userId, req.userId],
    (err, rows) => {
      if (err) return res.status(500).json({ error: "DB error" });
      res.json(rows);
    }
  );
});

app.get("/friends/:friendId/shared_habits", authenticateToken, (req, res) => {
  const friendId = parseInt(req.params.friendId, 10);
  db.all(
    `
    SELECT h1.title
    FROM habits h1
    JOIN habits h2
      ON h1.title = h2.title
     AND h1.user_id = ?
     AND h2.user_id = ?
    GROUP BY h1.title
    ORDER BY h1.title
    `,
    [req.userId, friendId],
    (err, rows) => {
      if (err) return res.status(500).json({ error: "DB error" });
      res.json(rows.map(r => r.title));
    }
  );
});

app.post("/friends/encourage", authenticateToken, (req, res) => {
  const { friendId, emoji = "👏", message } = req.body;
  // You can store it; here we just confirm:
  res.json({ ok: true, text: `${emoji} You encouraged user ${friendId}${message ? `: "${message}"` : ""}` });
});

function pair(x, y) {
  return x < y ? { a: x, b: y } : { a: y, b: x };
}


// ---------- Start server (single listen) ----------
app.listen(PORT, '0.0.0.0', () => console.log("Server running on http://0.0.0.0:3000"));
