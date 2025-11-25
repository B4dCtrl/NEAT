import React, { useState, useEffect } from 'react';
import Chat from './Chat';
import UserList from './UserList';
import Room from './Room';

const Sidebar = ({ socket, room, setRoom, username }) => {
    const [users, setUsers] = useState([]);
    const [messages, setMessages] = useState([]);

    useEffect(() => {
        if (socket) {
            socket.on('initialState', ({ users: initialUsers, messages: initialMessages }) => {
                setUsers(Object.values(initialUsers));
                setMessages(initialMessages);
            });
            socket.on('userJoined', (user) => {
                setUsers((prev) => [...prev, user]);
            });
            socket.on('userLeft', (id) => {
                setUsers((prev) => prev.filter(user => user.id !== id));
            });
            socket.on('newMessage', (message) => {
                setMessages((prev) => [...prev, message]);
            });
        }
        return () => {
            if (socket) {
                socket.off('initialState');
                socket.off('userJoined');
                socket.off('userLeft');
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
