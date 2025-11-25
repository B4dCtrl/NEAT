import React from 'react';

const Room = ({ socket, currentRoom, setRoom, username }) => {
    const rooms = ['open-space', 'meeting-room', 'lounge'];

    const handleRoomChange = (newRoom) => {
        if (newRoom !== currentRoom) {
            socket.emit('joinRoom', { username, room: newRoom });
            setRoom(newRoom);
        }
    };

    return (
        <div>
            <h3 className="text-xl mb-2">Rooms</h3>
            <div className="flex flex-col space-y-2">
                {rooms.map((room) => (
                    <button
                        key={room}
                        onClick={() => handleRoomChange(room)}
                        className={`p-2 rounded ${currentRoom === room ? 'bg-blue-600' : 'bg-gray-800 hover:bg-gray-900'}`}
                    >
                        {room}
                    </button>
                ))}
            </div>
        </div>
    );
};

export default Room;
