import { useEffect, useState, useRef } from 'react';
import io from 'socket.io-client';

const useSocket = (serverUrl) => {
    const socketRef = useRef(null);

    if (!socketRef.current) {
        socketRef.current = io(serverUrl);
    }

    useEffect(() => {
        const socket = socketRef.current;
        return () => {
            socket.disconnect();
        };
    }, []);

    return socketRef.current;
};

export default useSocket;
