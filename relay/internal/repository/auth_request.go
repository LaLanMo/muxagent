package repository

import (
	"context"
	"errors"
	"time"

	"github.com/LaLanMo/muxagent/relay/internal/domain"
	"github.com/LaLanMo/muxagent/relay/internal/repository/dao"
	"github.com/google/uuid"
)

type AuthRequestRepository interface {
	Create(ctx context.Context, req *domain.AuthRequest) error
	FindByID(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error)
	FindByIDForUpdate(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error)
	Update(ctx context.Context, req *domain.AuthRequest) error
	DeleteByID(ctx context.Context, id uuid.UUID) error
	DeleteExpired(ctx context.Context, cutoff time.Time) error
	NullifyExpiredPollTokens(ctx context.Context, cutoff time.Time) error
}

type authRequestRepository struct {
	dao dao.AuthRequestDAO
}

func NewAuthRequestRepository(dao dao.AuthRequestDAO) AuthRequestRepository {
	return &authRequestRepository{dao: dao}
}

func (r *authRequestRepository) Create(ctx context.Context, req *domain.AuthRequest) error {
	return r.dao.Create(ctx, toDAOAuthRequest(*req))
}

func (r *authRequestRepository) FindByID(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error) {
	req, err := r.dao.FindByID(ctx, id)
	if err != nil {
		if errors.Is(err, dao.ErrRecordNotFound) {
			return domain.AuthRequest{}, ErrAuthRequestNotFound
		}
		return domain.AuthRequest{}, err
	}
	return toDomainAuthRequest(*req), nil
}

func (r *authRequestRepository) FindByIDForUpdate(ctx context.Context, id uuid.UUID) (domain.AuthRequest, error) {
	req, err := r.dao.FindByIDForUpdate(ctx, id)
	if err != nil {
		if errors.Is(err, dao.ErrRecordNotFound) {
			return domain.AuthRequest{}, ErrAuthRequestNotFound
		}
		return domain.AuthRequest{}, err
	}
	return toDomainAuthRequest(*req), nil
}

func (r *authRequestRepository) Update(ctx context.Context, req *domain.AuthRequest) error {
	return r.dao.Update(ctx, toDAOAuthRequest(*req))
}

func (r *authRequestRepository) DeleteByID(ctx context.Context, id uuid.UUID) error {
	return r.dao.DeleteByID(ctx, id)
}

func (r *authRequestRepository) DeleteExpired(ctx context.Context, cutoff time.Time) error {
	return r.dao.DeleteExpired(ctx, cutoff)
}

func (r *authRequestRepository) NullifyExpiredPollTokens(ctx context.Context, cutoff time.Time) error {
	return r.dao.NullifyExpiredPollTokens(ctx, cutoff)
}

func toDomainAuthRequest(req dao.AuthRequest) domain.AuthRequest {
	return domain.AuthRequest{
		ID:                                 req.ID,
		MachineID:                          req.MachineID,
		MachineSignPub:                     req.MachineSignPub,
		MachineEncPub:                      req.MachineEncPub,
		Hostname:                           req.Hostname,
		CreatedAt:                          req.CreatedAt,
		ExpiresAt:                          req.ExpiresAt,
		RelayChallenge:                     req.RelayChallenge,
		PollToken:                          req.PollToken,
		ApprovedAt:                         req.ApprovedAt,
		ApprovedByMasterSignKeyFingerprint: req.ApprovedByMasterSignKeyFingerprint,
		ApprovalSignature:                  req.ApprovalSignature,
	}
}

func toDAOAuthRequest(req domain.AuthRequest) *dao.AuthRequest {
	return &dao.AuthRequest{
		ID:                                 req.ID,
		MachineID:                          req.MachineID,
		MachineSignPub:                     req.MachineSignPub,
		MachineEncPub:                      req.MachineEncPub,
		Hostname:                           req.Hostname,
		CreatedAt:                          req.CreatedAt,
		ExpiresAt:                          req.ExpiresAt,
		RelayChallenge:                     req.RelayChallenge,
		PollToken:                          req.PollToken,
		ApprovedAt:                         req.ApprovedAt,
		ApprovedByMasterSignKeyFingerprint: req.ApprovedByMasterSignKeyFingerprint,
		ApprovalSignature:                  req.ApprovalSignature,
	}
}
