package itn_orchestrator

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"github.com/Khan/genqlient/graphql"
)

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

type GetGqlClientF = func(context.Context, NodeAddress) (graphql.Client, error)

func GetGqlClient(sk ed25519.PrivateKey, nodes map[NodeAddress]NodeEntry) GetGqlClientF {
	authenticator := NewAuthenticator(sk, http.DefaultClient)
	return func(ctx context.Context, addr NodeAddress) (graphql.Client, error) {
		if entry, has := nodes[addr]; has {
			return entry.Client, nil
		}
		url := "http://" + string(addr) + "/graphql"
		authClient := graphql.NewClient(url, authenticator)
		resp, err := auth(ctx, authClient)
		if err != nil {
			return nil, fmt.Errorf("failed to authorize client %s: %v", addr, err)
		}
		seqAuthenticator := NewSequentialAuthenticator(resp.Auth.ServerUuid, resp.Auth.SignerSequenceNumber, authenticator)
		client := graphql.NewClient(url, seqAuthenticator)
		nodes[addr] = NodeEntry{
			Client:          client,
			Libp2pPort:      resp.Auth.Libp2pPort,
			PeerId:          resp.Auth.PeerId,
			IsBlockProducer: resp.Auth.IsBlockProducer,
		}
		return client, nil
	}
}

func SchedulePaymentsGql(ctx context.Context, client graphql.Client, input PaymentsDetails) (string, error) {
	resp, err := schedulePayments(ctx, client, input)
	if err != nil {
		return "", err
	}
	return resp.SchedulePayments, nil
}

func StopTransactionsGql(ctx context.Context, client graphql.Client, handle string) (string, error) {
	resp, err := stopScheduledTransactions(ctx, client, handle)
	if err != nil {
		return "", err
	}
	return resp.StopScheduledTransactions, nil
}

func ScheduleZkappCommands(ctx context.Context, client graphql.Client, input ZkappCommandsDetails) (string, error) {
	resp, err := scheduleZkappCommands(ctx, client, input)
	if err != nil {
		return "", err
	}
	return resp.ScheduleZkappCommands, nil
}

func SlotsWonGql(ctx context.Context, client graphql.Client) ([]int, error) {
	resp, err := slotsWon(ctx, client)
	if err != nil {
		return nil, err
	}
	return resp.SlotsWon, nil
}

func UpdateGatingGql(ctx context.Context, client graphql.Client, input GatingUpdate) (string, error) {
	resp, err := updateGating(ctx, client, input)
	if err != nil {
		return "", err
	}
	return resp.UpdateGating, nil
}
