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

app.post('/upload-fabric', upload.single('fabric'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ message: 'No file received' });
  }

  console.log('Image received:', req.file.filename);
  console.log('Image path sent to Python:', req.file.path);

  try {
    // Call Python ML service
    console.log('Sending to Python ML service...');
    const pythonResponse = await axios.post(
      'http://127.0.0.1:5000/analyze-fabric',
      {
        image_path: req.file.path
      },
      {
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );

    console.log('Python ML analysis complete');
    console.log('Python response:', pythonResponse.data);

    // Return ML results to Flutter
    res.status(200).json({
      message: 'Fabric analyzed',
      analysis: pythonResponse.data,
    });
  } catch (error) {
    console.error("Python service error:", error.message);
    if (error.response) {
      console.error("Python error response:", error.response.data);
      console.error("Python status code:", error.response.status);
    }

    // If Python service fails, still return success but without analysis
    res.status(200).json({
      message: 'Image uploaded but analysis unavailable',
      file: req.file.filename,
      analysis: {
        status: 'error',
        error: 'ML analysis service unavailable',
      },
    });
  }
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});

