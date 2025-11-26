import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { getStoredUser } from '../services/authService';
import './AdminPage.css';

const API_BASE_URL = 'http://localhost:3000/api/v1';

interface Membership {
  id: number;
  name: string;
  features: string;
  expires_at: string;
}

interface User {
  id: number;
  email: string;
  chat_coupons: number;
  membership: {
    id: number;
    name: string;
  } | null;
}

const AdminPage = () => {
  const navigate = useNavigate();
  const [memberships, setMemberships] = useState<Membership[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // 새 멤버십 폼
  const [newMembership, setNewMembership] = useState({
    name: '',
    features: '',
    duration_days: 30,
    coupon_count: 0
  });

  useEffect(() => {
    const user = getStoredUser();
    if (!user) {
      navigate('/login');
      return;
    }

    loadData();
  }, [navigate]);

  const loadData = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem('token');
      const headers = token ? { Authorization: `Bearer ${token}` } : {};

      // 멤버십 목록 로드
      const membershipsRes = await axios.get(`${API_BASE_URL}/memberships`, { headers });
      setMemberships(membershipsRes.data);

      // 사용자 목록 로드 (전체 사용자 조회)
      const usersRes = await axios.get(`${API_BASE_URL}/users`, { headers });
      setUsers(usersRes.data);
    } catch (err: any) {
      setError(err.response?.data?.error || '데이터 로드 실패');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateMembership = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    if (!newMembership.name || !newMembership.features) {
      setError('멤버십 이름과 기능을 입력해주세요.');
      return;
    }

    try {
      const token = localStorage.getItem('token');
      const headers = token ? { Authorization: `Bearer ${token}` } : {};

      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + newMembership.duration_days);

      await axios.post(
        `${API_BASE_URL}/memberships`,
        {
          membership: {
            name: newMembership.name,
            features: newMembership.features,
            expires_at: expiresAt.toISOString(),
            coupon_count: newMembership.coupon_count
          }
        },
        { headers }
      );

      setSuccess('멤버십이 생성되었습니다!');
      setNewMembership({ name: '', features: '', duration_days: 30, coupon_count: 0 });
      await loadData();
    } catch (err: any) {
      setError(err.response?.data?.errors?.join(', ') || '멤버십 생성 실패');
    }
  };

  const handleDeleteMembership = async (id: number, name: string) => {
    if (!window.confirm(`"${name}" 멤버십을 삭제하시겠습니까?`)) {
      return;
    }

    try {
      const token = localStorage.getItem('token');
      const headers = token ? { Authorization: `Bearer ${token}` } : {};

      await axios.delete(`${API_BASE_URL}/memberships/${id}`, { headers });
      setSuccess('멤버십이 삭제되었습니다!');
      await loadData();
    } catch (err: any) {
      setError(err.response?.data?.error || '멤버십 삭제 실패');
    }
  };

  const handleAssignMembership = async (userId: number, membershipId: number) => {
    try {
      const token = localStorage.getItem('token');
      const headers = token ? { Authorization: `Bearer ${token}` } : {};

      await axios.post(
        `${API_BASE_URL}/users/${userId}/assign_membership`,
        { membership_id: membershipId },
        { headers }
      );

      setSuccess('멤버십이 부여되었습니다!');
      await loadData();
    } catch (err: any) {
      setError(err.response?.data?.error || '멤버십 부여 실패');
    }
  };

  const handleRemoveMembership = async (userId: number, userEmail: string) => {
    if (!window.confirm(`"${userEmail}" 사용자의 멤버십을 회수하시겠습니까?`)) {
      return;
    }

    try {
      const token = localStorage.getItem('token');
      const headers = token ? { Authorization: `Bearer ${token}` } : {};

      await axios.delete(`${API_BASE_URL}/users/${userId}/remove_membership`, { headers });
      setSuccess('멤버십이 회수되었습니다!');
      await loadData();
    } catch (err: any) {
      setError(err.response?.data?.error || '멤버십 회수 실패');
    }
  };

  if (loading) {
    return (
      <div className="admin-container">
        <div className="loading">로딩 중...</div>
      </div>
    );
  }

  return (
    <div className="admin-container">
      <div className="admin-header">
        <h1>🔧 어드민 페이지</h1>
        <button className="back-button" onClick={() => navigate('/')}>
          ← 홈으로
        </button>
      </div>

      {error && (
        <div className="alert alert-error">
          ❌ {error}
          <button onClick={() => setError('')}>✕</button>
        </div>
      )}

      {success && (
        <div className="alert alert-success">
          ✅ {success}
          <button onClick={() => setSuccess('')}>✕</button>
        </div>
      )}

      {/* 멤버십 생성 섹션 */}
      <section className="admin-section">
        <h2>📝 새 멤버십 생성</h2>
        <form onSubmit={handleCreateMembership} className="membership-form">
          <div className="form-group">
            <label>멤버십 이름</label>
            <input
              type="text"
              value={newMembership.name}
              onChange={(e) => setNewMembership({ ...newMembership, name: e.target.value })}
              placeholder="예: 베이직, 프리미엄"
              required
            />
          </div>
          <div className="form-group">
            <label>기능 (쉼표로 구분)</label>
            <input
              type="text"
              value={newMembership.features}
              onChange={(e) => setNewMembership({ ...newMembership, features: e.target.value })}
              placeholder="예: 학습, 대화, 분석"
              required
            />
          </div>
          <div className="form-group">
            <label>유효 기간 (일)</label>
            <input
              type="number"
              value={newMembership.duration_days}
              onChange={(e) => setNewMembership({ ...newMembership, duration_days: Number(e.target.value) })}
              min="1"
              required
            />
          </div>
          <div className="form-group">
            <label>채팅 쿠폰 개수</label>
            <input
              type="number"
              value={newMembership.coupon_count}
              onChange={(e) => setNewMembership({ ...newMembership, coupon_count: Number(e.target.value) })}
              min="0"
              placeholder="0"
            />
          </div>
          <button type="submit" className="btn btn-primary">
            멤버십 생성
          </button>
        </form>
      </section>

      {/* 멤버십 목록 섹션 */}
      <section className="admin-section">
        <h2>📋 멤버십 목록</h2>
        <div className="memberships-grid">
          {memberships.map((membership) => (
            <div key={membership.id} className="membership-item">
              <div className="membership-item-header">
                <h3>{membership.name}</h3>
                <button
                  className="btn btn-danger btn-sm"
                  onClick={() => handleDeleteMembership(membership.id, membership.name)}
                >
                  삭제
                </button>
              </div>
              <div className="membership-item-body">
                <p>
                  <strong>기능:</strong> {membership.features}
                </p>
                <p>
                  <strong>만료일:</strong> {new Date(membership.expires_at).toLocaleDateString('ko-KR')}
                </p>
              </div>
            </div>
          ))}
        </div>
        {memberships.length === 0 && (
          <p className="empty-message">등록된 멤버십이 없습니다.</p>
        )}
      </section>

      {/* 사용자 관리 섹션 */}
      <section className="admin-section">
        <h2>👥 사용자 관리</h2>
        <div className="users-table-container">
          <table className="users-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>이메일</th>
                <th>현재 멤버십</th>
                <th>쿠폰</th>
                <th>작업</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.id}>
                  <td>{user.id}</td>
                  <td>{user.email}</td>
                  <td>
                    {user.membership ? (
                      <span className="badge badge-success">{user.membership.name}</span>
                    ) : (
                      <span className="badge badge-secondary">없음</span>
                    )}
                  </td>
                  <td>{user.chat_coupons || 0}개</td>
                  <td>
                    <div className="action-buttons">
                      <select
                        className="membership-select"
                        onChange={(e) => {
                          const membershipId = Number(e.target.value);
                          if (membershipId) {
                            handleAssignMembership(user.id, membershipId);
                            e.target.value = '';
                          }
                        }}
                        defaultValue=""
                      >
                        <option value="" disabled>
                          멤버십 부여
                        </option>
                        {memberships.map((m) => (
                          <option key={m.id} value={m.id}>
                            {m.name}
                          </option>
                        ))}
                      </select>
                      {user.membership && (
                        <button
                          className="btn btn-warning btn-sm"
                          onClick={() => handleRemoveMembership(user.id, user.email)}
                        >
                          회수
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {users.length === 0 && (
          <p className="empty-message">사용자가 없습니다.</p>
        )}
      </section>
    </div>
  );
};

export default AdminPage;

