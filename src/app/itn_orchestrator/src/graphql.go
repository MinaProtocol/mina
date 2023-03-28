package itn_orchestrator

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"io"
	"net/http"

	"github.com/Khan/genqlient/graphql"
)

func Auth(ctx context.Context, client graphql.Client) (bool, error) {
	resp, err := auth(ctx, client)
	if err != nil {
		return false, err
	}
	return resp.Auth, nil
}

type AuthenticatedClient struct {
	sk    ed25519.PrivateKey
	pkStr string
	doer  graphql.Doer
}

func NewAuthenticatedClient(sk ed25519.PrivateKey, doer graphql.Doer) *AuthenticatedClient {
	pk := sk.Public().(ed25519.PublicKey)
	return &AuthenticatedClient{
		sk: sk, doer: doer, pkStr: base64.StdEncoding.EncodeToString(pk),
	}
}

func readBody(req *http.Request) ([]byte, error) {
	readCloser, err := req.GetBody()
	if err != nil {
		return nil, err
	}
	defer readCloser.Close()
	return io.ReadAll(readCloser)
}

func (client *AuthenticatedClient) Do(req *http.Request) (*http.Response, error) {
	body, err := readBody(req)
	if err != nil {
		return nil, err
	}
	sig := ed25519.Sign(client.sk, body)
	sigStr := base64.StdEncoding.EncodeToString(sig)
	req.Header.Set("Authorization", "Signature "+client.pkStr+" "+sigStr)
	return client.doer.Do(req)
}

var _ graphql.Doer = (*AuthenticatedClient)(nil)

func SchedulePayments(ctx context.Context, client graphql.Client, input PaymentsDetails) (string, error) {
	resp, err := schedulePayments(ctx, client, input)
	if err != nil {
		return "", err
	}
	return resp.SchedulePayments, nil
}

func StopPayments(ctx context.Context, client graphql.Client, handle string) (string, error) {
	resp, err := stopPayments(ctx, client, handle)
	if err != nil {
		return "", err
	}
	return resp.StopPayments, nil
}
