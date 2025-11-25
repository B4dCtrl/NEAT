# 2D Multi-User Workspace

This project is a real-time 2D multi-user workspace application built with React, Node.js, Express, and Socket.IO. It provides a virtual office environment where multiple users can move around, interact, and communicate in real-time.

## Features

- **Real-time Movement**: Smooth, interpolated movement with collision detection.
- **Multi-user Support**: See other users move in real-time.
- **Room System**: Join different rooms ("open-space", "meeting-room", "lounge").
- **Text Chat**: Real-time chat for each room.
- **Modern UI**: Clean and modern UI built with React and TailwindCSS.
- **2D Graphics**: Rendered with the Canvas API.

## Folder Structure

```
.
├── client/         # React frontend
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── pages/
│   │   └── ...
│   ├── package.json
│   └── ...
├── server/         # Node.js backend
│   ├── server.js
│   └── package.json
└── README.md
```

## Prerequisites

- Node.js (v14 or higher)
- npm or yarn

## Getting Started

### 1. Clone the repository

```bash
git clone <repository-url>
cd <repository-directory>
```

### 2. Set up the server

```bash
cd server
npm install
npm start
```

The server will be running on `http://localhost:3000`.

### 3. Set up the client

In a new terminal window:

```bash
cd client
npm install
npm run dev
```

The client will be running on `http://localhost:5173` (or another port if 5173 is in use).

### 4. Open the application

Open your browser and navigate to the client URL. You will be prompted to enter your name and choose a room. Once you join, you will be able to see and interact with other users in the same room.
