import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getMemberships, Membership, purchaseMembership, createPayment } from '../services/membershipService';
import { getStoredUser } from '../services/authService';
import './MembershipPage.css';

const MembershipPage = () => {
  const [memberships, setMemberships] = useState<Membership[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>('');
  const [user, setUser] = useState<any>(null);
  const navigate = useNavigate();

  useEffect(() => {
    const storedUser = getStoredUser();
    if (!storedUser || !storedUser.id) {
      navigate('/login');
      return;
    }
    
    // 최신 사용자 정보 가져오기
    const fetchLatestUser = async () => {
      try {
        const token = localStorage.getItem('token');
        const headers: HeadersInit = token ? { Authorization: `Bearer ${token}` } : {};
        const response = await fetch(`http://localhost:3000/api/v1/users/${storedUser.id}`, { headers });
        
        if (response.ok) {
          const latestUser = await response.json();
          setUser(latestUser);
          localStorage.setItem('user', JSON.stringify(latestUser));
        } else {
          setUser(storedUser);
        }
      } catch (err) {
        setUser(storedUser);
      }
    };
    
    fetchLatestUser();
    loadMemberships();
  }, [navigate]);

  const loadMemberships = async () => {
    try {
      setLoading(true);
      const data = await getMemberships();
      setMemberships(data);
    } catch (err: any) {
      setError(err.message || '멤버십 목록을 불러올 수 없습니다.');
    } finally {
      setLoading(false);
    }
  };

  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [selectedMembership, setSelectedMembership] = useState<Membership | null>(null);
  const [cardNumber, setCardNumber] = useState<string>('');
  const [expiryDate, setExpiryDate] = useState<string>('');
  const [cvv, setCvv] = useState<string>('');

  const handlePurchaseClick = (membership: Membership) => {
    setSelectedMembership(membership);
    setShowPaymentModal(true);
    setCardNumber('');
    setExpiryDate('');
    setCvv('');
  };

  const handlePaymentSubmit = async () => {
    if (!user || !selectedMembership) return;

    setError('');
    
    try {
      // PG사 결제 API가 성공했다고 가정하는 Mock 결제 호출
      const result = await createPayment({
        membership_id: selectedMembership.id,
        payment_method: 'card',
        card_number: cardNumber || '4111111111111111',
        expiry_date: expiryDate || '12/26',
        cvv: cvv || '123'
      });
      
      // 사용자 정보 업데이트
      const updatedUser = { ...user, membership: result.user.membership };
      localStorage.setItem('user', JSON.stringify(updatedUser));
      setUser(updatedUser);

      setShowPaymentModal(false);
      setSelectedMembership(null);
      alert('멤버십 결제가 완료되었습니다!');
      navigate('/');
    } catch (err: any) {
      setError(err.message || '멤버십 구매에 실패했습니다.');
    }
  };


  const getChatCouponCount = (membership: Membership): number => {
    // 멤버십 객체에서 실제 쿠폰 개수 반환
    return membership.coupon_count || 0;
  };

  const getFeatures = (features: string[] | string): string[] => {
    if (Array.isArray(features)) {
      return features;
    }
    // features가 문자열인 경우 쉼표로 분리
    return features.split(',').map((f: string) => f.trim());
  };

  if (loading) {
    return (
      <div className="membership-container">
        <div className="loading">로딩 중...</div>
      </div>
    );
  }

  return (
    <div className="membership-container">
      <div className="membership-header">
        <h1>멤버십 선택</h1>
        <p>원하는 멤버십을 선택하여 서비스를 이용하세요</p>
        <button 
          className="back-button"
          onClick={() => navigate('/')}
        >
          ← 홈으로 돌아가기
        </button>
      </div>

      {error && (
        <div className="error-message">
          {error}
        </div>
      )}

      <div className="membership-grid">
        {memberships
          .map((membership) => {
            const couponCount = getChatCouponCount(membership);
            return (
              <div key={membership.id} className="membership-card">
                <div className="membership-name">{membership.name}</div>
                {couponCount > 0 && (
                  <div className="membership-price">
                    💬 대화 쿠폰 {couponCount}개
                  </div>
                )}
                
                <div className="membership-features">
                  <h3>포함 기능</h3>
                  <ul>
                    {getFeatures(membership.features).map((feature: string, index: number) => (
                      <li key={index}>✓ {feature}</li>
                    ))}
                  </ul>
                </div>

                <div className="membership-expires">
                  <small>만료일: {new Date(membership.expires_at).toLocaleDateString()}</small>
                </div>

                <button
                  className="purchase-button"
                  onClick={() => handlePurchaseClick(membership)}
                >
                  구매하기
                </button>
              </div>
            );
          })}
      </div>

      {memberships.length === 0 && (
        <div className="no-memberships">
          <p>현재 이용 가능한 멤버십이 없습니다.</p>
        </div>
      )}

      {/* 결제 모달 */}
      {showPaymentModal && selectedMembership && (
        <div className="modal-overlay" onClick={() => setShowPaymentModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{selectedMembership.name} 멤버십 결제</h3>
              <button 
                className="modal-close" 
                onClick={() => setShowPaymentModal(false)}
              >
                ✕
              </button>
            </div>
            <div className="modal-body">
              <div className="payment-info">
                <p><strong>멤버십:</strong> {selectedMembership.name}</p>
                <p><strong>기능:</strong> {getFeatures(selectedMembership.features).join(', ')}</p>
                <p><strong>만료일:</strong> {new Date(selectedMembership.expires_at).toLocaleDateString()}</p>
                {getChatCouponCount(selectedMembership) > 0 && (
                  <p><strong>채팅 쿠폰:</strong> {getChatCouponCount(selectedMembership)}개</p>
                )}
              </div>
              
              <div className="card-form">
                <h4>카드 정보 입력</h4>
                <div className="form-group">
                  <label>카드 번호</label>
                  <input
                    type="text"
                    placeholder="4111 1111 1111 1111"
                    value={cardNumber}
                    onChange={(e) => setCardNumber(e.target.value)}
                  />
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label>만료일 (MM/YY)</label>
                    <input
                      type="text"
                      placeholder="12/26"
                      value={expiryDate}
                      onChange={(e) => setExpiryDate(e.target.value)}
                    />
                  </div>
                  <div className="form-group">
                    <label>CVV</label>
                    <input
                      type="text"
                      placeholder="123"
                      value={cvv}
                      onChange={(e) => setCvv(e.target.value)}
                    />
                  </div>
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button 
                className="btn btn-secondary" 
                onClick={() => setShowPaymentModal(false)}
              >
                취소
              </button>
              <button 
                className="btn btn-primary" 
                onClick={handlePaymentSubmit}
              >
                결제하기
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default MembershipPage;
