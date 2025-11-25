import React, { useState, useEffect, useRef } from 'react';

const Chat = ({ socket, messages }) => {
    const [message, setMessage] = useState('');
    const messagesEndRef = useRef(null);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    };

    useEffect(() => {
        scrollToBottom();
    }, [messages]);

    const handleSendMessage = (e) => {
        e.preventDefault();
        if (message.trim() && socket) {
            socket.emit('sendMessage', message);
            setMessage('');
        }
    };

    return (
        <div className="flex-grow flex flex-col mt-4">
            <h3 className="text-xl mb-2">Chat</h3>
            <div className="flex-grow bg-gray-800 p-2 rounded overflow-y-auto h-40">
                {messages.map((msg, index) => (
                    <div key={index}>
                        <strong>{msg.username}:</strong> {msg.message}
                    </div>
                ))}
                <div ref={messagesEndRef} />
            </div>
            <form onSubmit={handleSendMessage} className="mt-2">
                <input
                    type="text"
                    value={message}
                    onChange={(e) => setMessage(e.target.value)}
                    placeholder="Type a message..."
                    className="w-full p-2 bg-gray-900 rounded"
                />
            </form>
        </div>
    );
};

export default Chat;
