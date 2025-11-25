import React, { useState } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Workspace from './pages/Workspace';
import LoginPage from './pages/LoginPage';
import AvatarEditor from './pages/AvatarEditor';

function App() {
  const [avatarData, setAvatarData] = useState({ color: '#ff0000' });

  const handleSaveAvatar = (data) => {
    setAvatarData(data);
  };

  return (
    <Router>
      <div className="w-screen h-screen bg-gray-800 text-white">
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            path="/avatar"
            element={<AvatarEditor onSave={handleSaveAvatar} />}
          />
          <Route path="/" element={<Workspace avatarData={avatarData} />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
