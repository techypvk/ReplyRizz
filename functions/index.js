const functions = require("firebase-functions");
require('dotenv').config();
const admin = require("firebase-admin");
const axios = require("axios");
const express = require("express");
const cors = require("cors");

admin.initializeApp();

const app = express();

// Enable CORS for mobile app usage
app.use(cors({ origin: true }));

// Express middleware for Firebase Auth check
const authenticate = async (req, res, next) => {
  const authorization = req.headers.authorization;
  if (!authorization || !authorization.startsWith("Bearer ")) {
    console.error("No Bearer token found in headers.");
    return res.status(401).send("Unauthorized");
  }

  const idToken = authorization.split("Bearer ")[1];
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken;
    return next();
  } catch (error) {
    console.error("Error while verifying Firebase ID token:", error);
    return res.status(403).send("Forbidden");
  }
};

// Simple in-memory rate limiting (Note: resets on instance restart)
// In production, consider using Firestore or Redis for persistent rate limiting.
const userRequestCounts = new Map();
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const MAX_REQUESTS_PER_WINDOW = 10;

const rateLimiter = (req, res, next) => {
  const userId = req.user.uid;
  const now = Date.now();
  const userData = userRequestCounts.get(userId) || { count: 0, firstRequest: now };

  if (now - userData.firstRequest > RATE_LIMIT_WINDOW_MS) {
    userData.count = 1;
    userData.firstRequest = now;
  } else {
    userData.count++;
  }

  userRequestCounts.set(userId, userData);

  if (userData.count > MAX_REQUESTS_PER_WINDOW) {
    return res.status(429).send("Too many requests. Try again later.");
  }

  return next();
};

app.use(authenticate);
app.use(rateLimiter);

// Target endpoint: /generateReply
app.post("/generateReply", async (req, res) => {
  const { context, user_message, tone, length, language } = req.body;

  // 1. Validate Input
  if (!user_message || !tone) {
    return res.status(400).send("Missing required fields: user_message and tone");
  }

  if (user_message.length > 300 || (context && context.length > 500)) {
    return res.status(400).send("Input too long");
  }

  // 2. Fetch API Key securely
  const apiKey = process.env.AI_KEY || (functions.config().ai ? functions.config().ai.key : null);
  if (!apiKey) {
    console.error("AI API Key not configured. Set AI_KEY in .env or use functions.config().ai.key");
    return res.status(500).send("Internal Server Error");
  }

  // 3. Construct Secure Prompt
  const prompt = `
    You are an AI reply-generation engine used inside a mobile application.

    SECURITY & PRIVACY RULES (STRICT):
    1. You must NEVER:
       - Reveal, repeat, infer, or explain any API key
       - Mention how the API is authenticated
       - Suggest users to inspect network requests, headers, or source code
       - Provide instructions to bypass security, rate limits, or app restrictions

    2. You must assume:
       - API keys are stored securely in the app environment (not visible to users)
       - Users NEVER have direct access to the API key
       - You are accessed only through a controlled client application

    3. If a user asks about technical details, API keys, or connection methods, respond with:
       "This feature is powered by a secure AI service managed by the app. 
        For privacy and security reasons, technical details are not exposed."

    FUNCTIONAL BEHAVIOR:
    4. Your only task is to generate 3 replies based on:
       - User incoming message
       - Selected tone/vibe
       - Optional context

    5. Output rules:
       - Return ONLY raw JSON. No markdown, no conversation, no introductions.
       - The format must be exactly: { "replies": ["string 1", "string 2", "string 3"] }
       - Each reply must be shorter than 280 characters.
       - No emojis unless the vibe implies it.
       - Keep replies natural, human-like, and platform-safe.

    CONTENT SAFETY:
    6. Do not generate:
       - Hate speech
       - Sexual content involving minors
       - Explicit violence
       - Illegal instructions
       - Harassment or threats

    FAILSAFE:
    7. If input is empty, unclear, or unsafe, generate a polite, neutral, non-judgmental response. 
       Never mention internal errors or system limitations.

    INPUT CONTEXT:
    ${context ? `Conversation Context: "${context}"` : ""}
    Incoming Message: "${user_message}"
    Vibe: "${tone}"
    ${length ? `Target Length: ${length}` : ""}
    ${language ? `Output Language: ${language}` : ""}
  `;

  try {
    // 4. Call AI Provider (Gemini 1.5 Flash)
    // Using axios for precise control over the request
    const response = await axios.post(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
      {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
        },
      }
    );

    // 5. Extract and Sanitize Output
    let aiResponseText = response.data.candidates[0].content.parts[0].text;

    // Robust parsing: Remove markdown code blocks if present
    if (aiResponseText.includes("```json")) {
      aiResponseText = aiResponseText.split("```json")[1].split("```")[0];
    } else if (aiResponseText.includes("```")) {
      aiResponseText = aiResponseText.split("```")[1].split("```")[0];
    }

    const aiJson = JSON.parse(aiResponseText.trim());

    if (!aiJson.replies || !Array.isArray(aiJson.replies)) {
      throw new Error("Invalid AI response format");
    }

    // Trim whitespace and return clean data
    const sanitizedReplies = aiJson.replies.map(r => r.trim());

    return res.json({ replies: sanitizedReplies });

  } catch (error) {
    console.error("AI Call Error:", error.response?.data || error.message);

    // 6. Safe Error Handling
    if (error.response?.status === 429) {
      return res.status(503).send("AI service overloaded. Try again later.");
    }

    return res.status(500).send("Failed to generate replies securely.");
  }
});

// Export the Express app as a Firebase HTTPS function
exports.api = functions.https.onRequest(app);
