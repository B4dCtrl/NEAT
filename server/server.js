const express = require('express');
const http = require('http');
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
  }
});

const rooms = {
  'open-space': { users: {}, messages: [] },
  'meeting-room': { users: {}, messages: [] },
  'lounge': { users: {}, messages: [] },
};

const mapDimensions = { width: 1000, height: 700 };
const walls = [
    { x: 0, y: 0, width: 1000, height: 10 },
    { x: 0, y: 0, width: 10, height: 700 },
    { x: 990, y: 0, width: 10, height: 700 },
    { x: 0, y: 690, width: 1000, height: 10 },
    { x: 100, y: 100, width: 150, height: 10 },
    { x: 100, y: 100, width: 10, height: 150 },
    { x: 300, y: 200, width: 200, height: 10 },
    { x: 500, y: 200, width: 10, height: 200 },
    { x: 700, y: 100, width: 10, height: 300 },
    { x: 700, y: 400, width: 150, height: 10 },
    { x: 200, y: 500, width: 250, height: 10 },
];

io.on('connection', (socket) => {
  console.log('a user connected:', socket.id);

  socket.on('joinRoom', ({ username, room }) => {
    if (!rooms[room]) {
        return;
    }
    socket.join(room);
    socket.username = username;
    socket.room = room;

    rooms[room].users[socket.id] = {
      id: socket.id,
      username,
      x: Math.random() * (mapDimensions.width - 100) + 50,
      y: Math.random() * (mapDimensions.height - 100) + 50,
    };

    socket.emit('initialState', { users: rooms[room].users, messages: rooms[room].messages, map: { dimensions: mapDimensions, walls } });
    socket.to(room).emit('userJoined', rooms[room].users[socket.id]);
  });

  socket.on('move', (position) => {
    if (socket.room && rooms[socket.room] && rooms[socket.room].users[socket.id]) {
        rooms[socket.room].users[socket.id].x = position.x;
        rooms[socket.room].users[socket.id].y = position.y;
        io.to(socket.room).emit('userMoved', { id: socket.id, x: position.x, y: position.y });
    }
  });

  socket.on('sendMessage', (message) => {
    if (socket.room && rooms[socket.room]) {
        const messageData = { username: socket.username, message };
        rooms[socket.room].messages.push(messageData);
        if (rooms[socket.room].messages.length > 50) {
            rooms[socket.room].messages.shift();
        }
        io.to(socket.room).emit('newMessage', messageData);
    }
  });

  socket.on('disconnect', () => {
    console.log('user disconnected:', socket.id);
    if (socket.room && rooms[socket.room] && rooms[socket.room].users[socket.id]) {
        delete rooms[socket.room].users[socket.id];
        io.to(socket.room).emit('userLeft', socket.id);
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
