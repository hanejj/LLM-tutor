import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { isAuthenticated, getStoredUser, logout } from '../services/authService';
import './HomePage.css';
import { FEATURE_CHAT } from '../constants/features';

/**
 * 멤버십 정보 인터페이스
 */
interface Membership {
  id: number;
  name: string;
  features: string[] | string;
  expires_at: string;
}

/**
 * 사용자 정보 인터페이스
 */
interface User {
  id: number;
  email: string;
  chat_coupons: number;
  membership: Membership | null;
}

/**
 * 홈페이지 컴포넌트
 * 사용자 정보를 표시하고 멤버십 상태를 관리합니다.
 */
const HomePage = () => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    // 인증 상태 확인
    if (!isAuthenticated()) {
      navigate('/login');
      return;
    }

    // 저장된 사용자 정보에서 ID 가져오기
    const storedUser = getStoredUser();
    if (!storedUser || !storedUser.id) {
      navigate('/login');
      return;
    }

    // 서버에서 최신 사용자 정보 가져오기
    const token = localStorage.getItem('token');
    const headers = token ? { Authorization: `Bearer ${token}` } : {};

    axios.get<User>(`http://localhost:3000/api/v1/users/${storedUser.id}`, { headers })
      .then((res) => {
        setUser(res.data);
        // localStorage도 업데이트
        localStorage.setItem('user', JSON.stringify(res.data));
      })
      .catch((err) => {
        // 에러 시 로그아웃 처리
        if (err.response?.status === 401 || err.response?.status === 404) {
          localStorage.removeItem('token');
          localStorage.removeItem('user');
          navigate('/login');
        }
      })
      .finally(() => {
        setLoading(false);
      });
  }, [navigate]);

  /**
   * 로그아웃 처리
   * 서버에 로그아웃 요청을 보내고 로그인 페이지로 이동합니다.
   */
  const handleLogout = async () => {
    try {
      await logout();
      navigate('/login');
    } catch (error) {
      // 에러가 발생해도 클라이언트 측에서 로그아웃 처리
      navigate('/login');
    }
  };

  if (loading) {
    return (
      <div className="home-container">
        <div className="home-card">
          <div className="loading">로딩 중...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="home-container">
      <div className="home-card">
        <div className="home-header">
          <h1 className="home-title">홈</h1>
          <div style={{ display: 'flex', gap: '10px' }}>
            <button 
              onClick={() => navigate('/admin')}
              className="admin-button"
              style={{ 
                background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                color: 'white',
                border: 'none',
                padding: '10px 20px',
                borderRadius: '8px',
                cursor: 'pointer',
                fontSize: '0.9rem',
                fontWeight: '600'
              }}
            >
              🔧 어드민
            </button>
            <button 
              onClick={handleLogout}
              className="logout-button"
            >
              로그아웃
            </button>
          </div>
        </div>

        <div className="user-info">
          <p className="user-email">이메일: {user?.email}</p>
          <p className="user-coupons" style={{ 
            marginTop: '8px',
            fontSize: '1rem',
            color: '#4f46e5',
            fontWeight: '600'
          }}>
            💬 보유 쿠폰: {user?.chat_coupons || 0}개
          </p>
        </div>

        <div className="membership-section">
          {user?.membership ? (
            <div>
              <h2 className="membership-title success">
                ✅ 멤버십 정보
              </h2>
              <div className="membership-info">
                <div className="membership-details">
                  <div className="membership-detail">
                    <div className="membership-detail-label">멤버십 종류</div>
                    <div className="membership-detail-value">{user.membership.name}</div>
                  </div>
                  <div className="membership-detail">
                    <div className="membership-detail-label">만료일</div>
                    {(() => {
                      const exp = new Date(user.membership!.expires_at).getTime();
                      const now = Date.now();
                      const msLeft = exp - now;
                      const daysLeft = Math.ceil(msLeft / (1000 * 60 * 60 * 24));
                      const isExpired = msLeft < 0;
                      const isExpiringSoon = !isExpired && daysLeft <= 7;
                      return (
                        <div className="membership-detail-value" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          {new Date(user.membership!.expires_at).toLocaleDateString()}
                          {isExpired && (
                            <span style={{
                              background: '#fee2e2', color: '#b91c1c', padding: '2px 8px', borderRadius: 12,
                              fontSize: '0.8rem', fontWeight: 700
                            }}>만료됨</span>
                          )}
                          {isExpiringSoon && (
                            <span style={{
                              background: '#fef3c7', color: '#92400e', padding: '2px 8px', borderRadius: 12,
                              fontSize: '0.8rem', fontWeight: 700
                            }}>만료 임박 · {daysLeft}일 남음</span>
                          )}
                        </div>
                      );
                    })()}
                  </div>
                </div>
                <div className="membership-features">
                  <div className="membership-features-title">포함 기능</div>
                  <div className="membership-features-list">
                    {(
                      Array.isArray(user.membership.features)
                        ? user.membership.features
                        : String(user.membership.features || '')
                            .split(',')
                            .map((f) => f.trim())
                    ).map((feature: string, index: number) => (
                      <span key={index} className="membership-feature-tag">
                        {feature}
                      </span>
                    ))}
                  </div>
                </div>
                {(() => {
                  const featuresArr = Array.isArray(user.membership.features)
                    ? user.membership.features
                    : String(user.membership.features || '')
                        .split(',')
                        .map((f) => f.trim());
                  const hasChat = featuresArr.includes(FEATURE_CHAT);
                  const exp = new Date(user.membership!.expires_at).getTime();
                  const isExpired = exp < Date.now();
                  const hasCoupons = (user.chat_coupons || 0) > 0;
                  return (
                    <div style={{ marginTop: 16, display: 'flex', gap: '12px' }}>
                      <button
                        className="purchase-button"
                        onClick={() => navigate('/chat')}
                        disabled={!hasChat || isExpired || !hasCoupons}
                        title={
                          !hasChat
                            ? '대화 기능이 포함된 멤버십이 필요합니다'
                            : isExpired
                              ? '만료된 멤버십입니다'
                              : !hasCoupons
                                ? '남은 채팅 쿠폰이 없습니다'
                                : ''
                        }
                      >
                        대화 시작
                      </button>
                      <button
                        className="purchase-button"
                        onClick={() => navigate('/membership')}
                        style={{ background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)' }}
                      >
                        추가 멤버십 구매
                      </button>
                    </div>
                  );
                })()}
              </div>
            </div>
          ) : (
            <div>
              <h2 className="membership-title error">
                ❌ 멤버십이 없습니다
              </h2>
              <div className="no-membership">
                <div className="no-membership-title">
                  멤버십을 구매하여 더 많은 기능을 이용하세요
                </div>
                <p className="no-membership-description">
                  다양한 멤버십 옵션을 확인하고 원하는 기능을 선택하세요.
                </p>
                <button 
                  onClick={() => navigate('/membership')}
                  className="purchase-button"
                >
                  멤버십 구매하기
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default HomePage;
