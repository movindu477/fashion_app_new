const express = require('express');
const multer = require('multer');
const cors = require('cors');
const axios = require('axios');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

const storage = multer.diskStorage({
  destination: 'uploads/',
  filename: (req, file, cb) => {
    cb(null, Date.now() + '-' + file.originalname);
  },
});

const upload = multer({ storage });

// 📡 PING ROUTE TO TEST CONNECTIVITY
app.get("/ping", (req, res) => {
  console.log("📡 Ping received from device");
  res.json({ status: "ok" });
});

app.post('/upload-fabric', upload.single('fabric'), async (req, res) => {
  console.log("🔥 /upload-fabric endpoint HIT");

  if (!req.file) {
    console.error("❌ No file received");
    return res.status(400).json({ status: "error", message: "No file received" });
  }

  console.log("✅ Image received:", req.file.filename);
  console.log("➡️ Sending to Python:", req.file.path);

  try {
    const pythonResponse = await axios.post(
      'http://127.0.0.1:5000/analyze-fabric',
      { image_path: req.file.path },
      { timeout: 8000 } // ⬅ VERY IMPORTANT
    );

    console.log("✅ Python responded");

    return res.status(200).json({
      status: "success",
      analysis: pythonResponse.data,
    });

  } catch (error) {
    console.error("❌ Python error:", error.message);

    // 🔴 ALWAYS RESPOND
    return res.status(200).json({
      status: "partial",
      message: "Image uploaded, ML failed",
      error: error.message,
    });
  }
});

app.get('/', (req, res) => {
  res.send('Fashion App Backend is Running!');
});

// ✅ LISTEN ON ALL INTERFACES
app.listen(3000, "0.0.0.0", () => {
  console.log("Server running on port 3000");
  console.log("Listening on all network interfaces (0.0.0.0)");
  console.log("Accessible at http://localhost:3000 locally");
  console.log("Accessible at http://<your-ip>:3000 from mobile devices");
});
