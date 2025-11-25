import { useEffect, useState, useRef } from 'react';
import io from 'socket.io-client';

const useSocket = (serverUrl) => {
    const [socket, setSocket] = useState(null);
    const socketRef = useRef(null);

    useEffect(() => {
        const newSocket = io(serverUrl);
        socketRef.current = newSocket;
        setSocket(newSocket);

        return () => {
            newSocket.disconnect();
        };
    }, [serverUrl]);

    return socket;
};

export default useSocket;
