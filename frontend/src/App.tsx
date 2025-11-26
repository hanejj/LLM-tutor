import React from 'react';
import { Routes, Route } from 'react-router-dom';
import HomePage from './pages/HomePage';
import ChatPage from './pages/ChatPage';
import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import MembershipPage from './pages/MembershipPage';
import AdminPage from './pages/AdminPage';

/**
 * 메인 앱 컴포넌트
 * 라우팅 설정을 담당합니다.
 */
const App = () => {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/register" element={<RegisterPage />} />
      <Route path="/membership" element={<MembershipPage />} />
      <Route path="/chat" element={<ChatPage />} />
      <Route path="/admin" element={<AdminPage />} />
    </Routes>
  );
};

export default App;
