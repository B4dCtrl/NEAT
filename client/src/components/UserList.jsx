import React from 'react';

const UserList = ({ users }) => {
    return (
        <div className="mt-4">
            <h3 className="text-xl mb-2">Users ({users.length})</h3>
            <ul className="bg-gray-800 p-2 rounded">
                {users.map((user) => (
                    <li key={user.id}>{user.username}</li>
                ))}
            </ul>
        </div>
    );
};

export default UserList;
