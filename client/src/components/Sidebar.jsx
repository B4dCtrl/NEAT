import React, { useState, useEffect } from 'react';
import Chat from './Chat';
import UserList from './UserList';
import Room from './Room';

const Sidebar = ({ socket, room, setRoom, username, users }) => {
    const [messages, setMessages] = useState([]);

    useEffect(() => {
        if (socket) {
            socket.on('newMessage', (message) => {
                setMessages((prev) => [...prev, message]);
            });
        }
        return () => {
            if (socket) {
                socket.off('newMessage');
            }
        };
    }, [socket]);

    return (
        <div className="w-80 bg-gray-700 p-4 flex flex-col">
            <Room socket={socket} currentRoom={room} setRoom={setRoom} username={username} />
            <UserList users={users} />
            <Chat socket={socket} messages={messages} />
        </div>
    );
};

export default Sidebar;
