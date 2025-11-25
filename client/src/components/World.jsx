import React, { useRef, useEffect, useState } from 'react';

const PLAYER_SIZE = 20;
const PLAYER_SPEED = 3;
const INTERPOLATION_FACTOR = 0.1;

const World = ({ socket, users, setUsers }) => {
    const canvasRef = useRef(null);
    const [map, setMap] = useState({ dimensions: { width: 0, height: 0 }, walls: [] });
    const [messages, setMessages] = useState([]);
    const keysPressed = useRef({});
    const localPlayerPos = useRef({ x: 0, y: 0 });
    const targetPos = useRef(null);
    const remotePlayerTargets = useRef({});

    const checkCollision = (newX, newY) => {
        for (const wall of map.walls) {
            if (
                newX < wall.x + wall.width &&
                newX + PLAYER_SIZE > wall.x &&
                newY < wall.y + wall.height &&
                newY + PLAYER_SIZE > wall.y
            ) {
                return true;
            }
        }
        return false;
    };

    useEffect(() => {
        const canvas = canvasRef.current;
        const context = canvas.getContext('2d');
        let animationFrameId;

        const draw = () => {
            context.clearRect(0, 0, canvas.width, canvas.height);
            
            context.fillStyle = '#3d4451';
            context.fillRect(0, 0, canvas.width, canvas.height);

            context.fillStyle = '#2d333b';
            map.walls.forEach(wall => {
                context.fillRect(wall.x, wall.y, wall.width, wall.height);
            });

            for (const id in users) {
                const user = users[id];
                if (id !== socket.id) {
                    const target = remotePlayerTargets.current[id];
                    if (target) {
                        user.x += (target.x - user.x) * INTERPOLATION_FACTOR;
                        user.y += (target.y - user.y) * INTERPOLATION_FACTOR;
                    }
                }
                
                context.fillStyle = user.avatarData?.color || (id === socket.id ? '#1e90ff' : '#a9a9a9');
                context.beginPath();
                context.arc(user.x, user.y, PLAYER_SIZE / 2, 0, 2 * Math.PI);
                context.fill();

                context.fillStyle = '#ffffff';
                context.fillText(user.username, user.x - context.measureText(user.username).width / 2, user.y - 15);
            }

            messages.forEach((msg, index) => {
                const user = users[msg.id];
                if (user) {
                    const x = user.x;
                    const y = user.y - 30;
                    const text = msg.message;
                    const textWidth = context.measureText(text).width;

                    context.fillStyle = 'rgba(0, 0, 0, 0.5)';
                    context.fillRect(x - textWidth / 2 - 5, y - 15, textWidth + 10, 20);

                    context.fillStyle = '#ffffff';
                    context.fillText(text, x - textWidth / 2, y);
                }
            });

            animationFrameId = requestAnimationFrame(draw);
        };

        if (socket) {
            socket.on('initialState', ({ map: initialMap }) => {
                setMap(initialMap);
                canvasRef.current.width = initialMap.dimensions.width;
                canvasRef.current.height = initialMap.dimensions.height;
                if(users[socket.id]) {
                    localPlayerPos.current = { x: users[socket.id].x, y: users[socket.id].y };
                }
            });

            socket.on('userMoved', ({ id, x, y }) => {
                if (id !== socket.id) {
                    remotePlayerTargets.current[id] = { x, y };
                }
            });

            socket.on('newMessage', (message) => {
                setMessages((prev) => [...prev, message]);
                setTimeout(() => {
                    setMessages((prev) => prev.filter((msg) => msg !== message));
                }, 5000);
            });

            draw();
        }

        return () => {
            cancelAnimationFrame(animationFrameId);
            if(socket) {
                socket.off('initialState');
                socket.off('userJoined');
                socket.off('userLeft');
                socket.off('userMoved');
            }
        };
    }, [socket, users, map]);
    
    useEffect(() => {
        const handleKeyDown = (e) => { keysPressed.current[e.key.toLowerCase()] = true; };
        const handleKeyUp = (e) => { keysPressed.current[e.key.toLowerCase()] = false; };
        const handleMouseDown = (e) => {
            const rect = canvasRef.current.getBoundingClientRect();
            targetPos.current = { x: e.clientX - rect.left, y: e.clientY - rect.top };
        };

        window.addEventListener('keydown', handleKeyDown);
        window.addEventListener('keyup', handleKeyUp);
        const canvas = canvasRef.current;
        canvas.addEventListener('mousedown', handleMouseDown);

        let gameLoopId;
        const gameLoop = () => {
            if (users[socket.id]) {
                let { x, y } = users[socket.id];
                let moved = false;

                if (targetPos.current) {
                    const dx = targetPos.current.x - x;
                    const dy = targetPos.current.y - y;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist < PLAYER_SPEED) {
                        targetPos.current = null;
                    } else {
                        x += (dx / dist) * PLAYER_SPEED;
                        y += (dy / dist) * PLAYER_SPEED;
                        moved = true;
                    }
                }

                let dx = 0;
                let dy = 0;
                if (keysPressed.current['w']) dy -= PLAYER_SPEED;
                if (keysPressed.current['s']) dy += PLAYER_SPEED;
                if (keysPressed.current['a']) dx -= PLAYER_SPEED;
                if (keysPressed.current['d']) dx += PLAYER_SPEED;

                if (dx !== 0 || dy !== 0) {
                    targetPos.current = null;
                    if (!checkCollision(x + dx, y)) x += dx;
                    if (!checkCollision(x, y + dy)) y += dy;
                    moved = true;
                }

                if (moved) {
                    setUsers(prev => ({...prev, [socket.id]: {...prev[socket.id], x,y}}))
                    socket.emit('move', { x, y });
                }
            }
            gameLoopId = setTimeout(gameLoop, 1000/60);
        };
        gameLoop();

        return () => {
            window.removeEventListener('keydown', handleKeyDown);
            window.removeEventListener('keyup', handleKeyUp);
            canvas.removeEventListener('mousedown', handleMouseDown);
            clearTimeout(gameLoopId);
        };
    }, [socket, users]);

    return (
        <div className="flex-grow bg-gray-900 overflow-auto">
             <canvas ref={canvasRef} />
        </div>
    );
};

export default World;
