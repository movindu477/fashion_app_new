# Backend Services - Quick Start Guide

## 🚀 Quick Start (Easiest Way)

### Option 1: Start Everything at Once
Double-click: **`START_ALL_SERVICES.bat`**

This will open 2 terminal windows:
- Node.js Backend (port 3000)
- Python ML Service (port 5000)

---

## 📋 Manual Start (Step by Step)

### Step 1: Start Node.js Backend
```bash
cd backend
node server.js
```
Or double-click: `backend/start-nodejs.bat`

**Expected output:** `Server running on port 3000`

### Step 2: Start Python ML Service
Open a **NEW** terminal window:
```bash
cd backend/python
python fabric_analysis.py
```
Or double-click: `backend/python/start-python.bat`

**Expected output:** `Running on http://127.0.0.1:5000`

### Step 3: Start Flutter App
Open a **NEW** terminal window:
```bash
flutter run
```

---

## ✅ Service Status Checklist

Before testing, verify all services are running:

- [ ] Node.js terminal shows: "Server running on port 3000"
- [ ] Python terminal shows: "Running on http://127.0.0.1:5000"
- [ ] Flutter app is running on your phone/emulator

---

## 🔧 Installation (First Time Only)

### Node.js Dependencies
```bash
cd backend
npm install
```

### Python Dependencies
```bash
cd backend/python
pip install -r requirements.txt
```

---

## 🛑 Stopping Services

- Close each terminal window individually, OR
- Press `Ctrl+C` in each terminal window

---

## 📡 Ports Used

- **3000** - Node.js Backend (receives images from Flutter)
- **5000** - Python ML Service (analyzes images)

---

## 🔍 Testing

1. Start all services (see above)
2. Open Flutter app on your phone
3. Capture a fabric image
4. Tap "Analyze Fabric"
5. Check:
   - Node.js terminal: Should show "Image received: [filename]"
   - Python terminal: Should show analysis request
   - Flutter app: Should show success message

