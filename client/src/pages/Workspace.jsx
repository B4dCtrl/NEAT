import React, { useState, useEffect } from 'react';
import useSocket from '../hooks/useSocket';
import World from '../components/World';
import Sidebar from '../components/Sidebar';

const SERVER_URL = 'http://localhost:3000';

const Workspace = () => {
    const [username, setUsername] = useState('');
    const [room, setRoom] = useState('open-space');
    const [isConnected, setIsConnected] = useState(false);
    const socket = useSocket(SERVER_URL);

    const handleJoin = (e) => {
        e.preventDefault();
        if (username.trim() && room.trim() && socket) {
            socket.emit('joinRoom', { username, room });
            setIsConnected(true);
        }
    };

    if (!isConnected) {
        return (
            <div className="flex items-center justify-center h-full">
                <form onSubmit={handleJoin} className="bg-gray-700 p-8 rounded-lg shadow-lg">
                    <h2 className="text-2xl mb-4">Join a Room</h2>
                    <input
                        type="text"
                        value={username}
                        onChange={(e) => setUsername(e.target.value)}
                        placeholder="Enter your name"
                        className="w-full p-2 mb-4 bg-gray-800 rounded"
                    />
                    <select value={room} onChange={(e) => setRoom(e.target.value)} className="w-full p-2 mb-4 bg-gray-800 rounded">
                        <option value="open-space">Open Space</option>
                        <option value="meeting-room">Meeting Room</option>
                        <option value="lounge">Lounge</option>
                    </select>
                    <button type="submit" className="w-full p-2 bg-blue-600 rounded hover:bg-blue-700">
                        Join
                    </button>
                </form>
            </div>
        );
    }

    return (
        <div className="flex h-full">
            <World socket={socket} />
            <Sidebar socket={socket} room={room} setRoom={setRoom} username={username} />
        </div>
    );
};

export default Workspace;
