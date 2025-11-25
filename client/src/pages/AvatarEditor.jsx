import React, { useState } from 'react';

const AvatarEditor = ({ onSave }) => {
  const [color, setColor] = useState('#ff0000');

  const handleSave = () => {
    onSave({ color });
  };

  return (
    <div className="flex items-center justify-center h-screen bg-gray-100">
      <div className="w-full max-w-md p-8 space-y-6 bg-white rounded-lg shadow-md">
        <h2 className="text-2xl font-bold text-center text-gray-900">
          Avatar Editor
        </h2>
        <div className="flex flex-col items-center space-y-4">
          <label htmlFor="color" className="text-sm font-medium text-gray-700">
            Avatar Color
          </label>
          <input
            id="color"
            name="color"
            type="color"
            value={color}
            onChange={(e) => setColor(e.target.value)}
            className="w-24 h-12 p-1 border border-gray-300 rounded-md"
          />
          <div
            className="w-24 h-24 rounded-full"
            style={{ backgroundColor: color }}
          />
        </div>
        <button
          onClick={handleSave}
          className="w-full px-4 py-2 text-sm font-medium text-white bg-indigo-600 border border-transparent rounded-md shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          Save
        </button>
      </div>
    </div>
  );
};

export default AvatarEditor;
