import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { register } from '../services/authService';
import './RegisterPage.css';

interface RegisterFormData {
  email: string;
  password: string;
  password_confirmation: string;
}

const RegisterPage = () => {
  const [formData, setFormData] = useState<RegisterFormData>({
    email: '',
    password: '',
    password_confirmation: ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>('');
  const navigate = useNavigate();

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
    // 에러 메시지 초기화
    if (error) setError('');
  };

  const validateForm = (): boolean => {
    if (!formData.email.trim()) {
      setError('이메일을 입력해주세요.');
      return false;
    }
    if (!formData.password.trim()) {
      setError('비밀번호를 입력해주세요.');
      return false;
    }
    if (!formData.password_confirmation.trim()) {
      setError('비밀번호 확인을 입력해주세요.');
      return false;
    }
    if (!/\S+@\S+\.\S+/.test(formData.email)) {
      setError('올바른 이메일 형식을 입력해주세요.');
      return false;
    }
    if (formData.password.length < 6) {
      setError('비밀번호는 최소 6자리 이상이어야 합니다.');
      return false;
    }
    if (formData.password !== formData.password_confirmation) {
      setError('비밀번호와 비밀번호 확인이 일치하지 않습니다.');
      return false;
    }
    return true;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) return;

    setLoading(true);
    setError('');

    try {
      // authService를 사용한 회원가입 API 호출
      const response = await register({
        email: formData.email,
        password: formData.password,
        password_confirmation: formData.password_confirmation
      });

      // 회원가입 성공 시 토큰과 사용자 정보 저장
      localStorage.setItem('token', response.token);
      localStorage.setItem('user', JSON.stringify(response.user));

      // 홈페이지로 리다이렉트
      navigate('/');
    } catch (err: any) {
      setError(err.message || '회원가입 중 오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="register-container">
      <div className="register-card">
        <div className="register-header">
          <h1>회원가입</h1>
          <p>새 계정을 만들어 서비스를 이용하세요</p>
        </div>

        <form onSubmit={handleSubmit} className="register-form">
          <div className="form-group">
            <label htmlFor="email">이메일</label>
            <input
              type="email"
              id="email"
              name="email"
              value={formData.email}
              onChange={handleInputChange}
              placeholder="이메일을 입력하세요"
              disabled={loading}
              className={error && !formData.email ? 'error' : ''}
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">비밀번호</label>
            <input
              type="password"
              id="password"
              name="password"
              value={formData.password}
              onChange={handleInputChange}
              placeholder="비밀번호를 입력하세요 (최소 6자리)"
              disabled={loading}
              className={error && !formData.password ? 'error' : ''}
            />
          </div>

          <div className="form-group">
            <label htmlFor="password_confirmation">비밀번호 확인</label>
            <input
              type="password"
              id="password_confirmation"
              name="password_confirmation"
              value={formData.password_confirmation}
              onChange={handleInputChange}
              placeholder="비밀번호를 다시 입력하세요"
              disabled={loading}
              className={error && !formData.password_confirmation ? 'error' : ''}
            />
          </div>

          {error && (
            <div className="error-message">
              {error}
            </div>
          )}

          <button 
            type="submit" 
            className="register-button"
            disabled={loading}
          >
            {loading ? '회원가입 중...' : '회원가입'}
          </button>
        </form>

        <div className="register-footer">
          <p>
            이미 계정이 있으신가요?{' '}
            <Link to="/login" className="link-button">
              로그인
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
};

export default RegisterPage;
