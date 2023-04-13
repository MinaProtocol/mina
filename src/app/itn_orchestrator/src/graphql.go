package itn_orchestrator

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/binary"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/Khan/genqlient/graphql"
)

func Auth(ctx context.Context, client graphql.Client) (string, uint16, error) {
	resp, err := auth(ctx, client)
	if err != nil {
		return "", 0, err
	}
	return resp.Auth.ServerUuid, resp.Auth.SignerSequenceNumber, nil
}

type Authenticator struct {
	sk    ed25519.PrivateKey
	pkStr string
	doer  graphql.Doer
}

type SequentialAuthenticator struct {
	Authenticator
	uuid  string
	seqno uint16
}

func NewAuthenticator(sk ed25519.PrivateKey, doer graphql.Doer) *Authenticator {
	pk := sk.Public().(ed25519.PublicKey)
	return &Authenticator{
		sk: sk, doer: doer, pkStr: base64.StdEncoding.EncodeToString(pk),
	}
}

func NewSequentialAuthenticator(uuid string, seqno uint16, authenticator *Authenticator) *SequentialAuthenticator {
	return &SequentialAuthenticator{
		Authenticator: *authenticator,
		uuid:          uuid,
		seqno:         seqno,
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

func (client *Authenticator) Do(req *http.Request) (*http.Response, error) {
	body, err := readBody(req)
	if err != nil {
		return nil, err
	}
	sig := ed25519.Sign(client.sk, body)
	sigStr := base64.StdEncoding.EncodeToString(sig)
	req.Header.Set("Authorization", "Signature "+client.pkStr+" "+sigStr)
	return client.doer.Do(req)
}

var _ graphql.Doer = (*Authenticator)(nil)

func (client *SequentialAuthenticator) Do(req *http.Request) (*http.Response, error) {
	body, err := readBody(req)
	if err != nil {
		return nil, err
	}
	uuid := []byte(client.uuid)
	msg := make([]byte, len(body)+len(client.uuid)+2)
	binary.BigEndian.PutUint16(msg, client.seqno)
	copy(msg[2:], uuid)
	copy(msg[2+len(uuid):], body)
	sig := ed25519.Sign(client.sk, msg)
	sigStr := base64.StdEncoding.EncodeToString(sig)
	header := strings.Join([]string{
		"Signature",
		client.pkStr,
		sigStr,
		"; Sequencing",
		client.uuid,
		strconv.Itoa(int(client.seqno)),
	}, " ")
	req.Header.Set("Authorization", header)
	client.seqno++
	return client.doer.Do(req)
}

var _ graphql.Doer = (*SequentialAuthenticator)(nil)

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
