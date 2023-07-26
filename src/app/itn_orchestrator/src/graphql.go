package itn_orchestrator

import (
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

type DoerWithStatus struct {
	Doer           graphql.Doer
	LastStatusCode int
}

type Authenticator struct {
	sk    ed25519.PrivateKey
	pkStr string
	doer  DoerWithStatus
}

func (doer *DoerWithStatus) Do(req *http.Request) (*http.Response, error) {
	resp, err := doer.Doer.Do(req)
	if err == nil {
		doer.LastStatusCode = resp.StatusCode
	}
	return resp, err
}

type SequentialAuthenticator struct {
	authenticator *Authenticator
	uuid          string
	seqno         uint16
}

func NewAuthenticator(sk ed25519.PrivateKey, doer graphql.Doer) *Authenticator {
	pk := sk.Public().(ed25519.PublicKey)
	return &Authenticator{
		sk: sk, doer: DoerWithStatus{Doer: doer}, pkStr: base64.StdEncoding.EncodeToString(pk),
	}
}

func NewSequentialAuthenticator(uuid string, seqno uint16, authenticator *Authenticator) *SequentialAuthenticator {
	return &SequentialAuthenticator{
		authenticator: authenticator,
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
	sig := ed25519.Sign(client.authenticator.sk, msg)
	sigStr := base64.StdEncoding.EncodeToString(sig)
	header := strings.Join([]string{
		"Signature",
		client.authenticator.pkStr,
		sigStr,
		"; Sequencing",
		client.uuid,
		strconv.Itoa(int(client.seqno)),
	}, " ")
	req.Header.Set("Authorization", header)
	client.seqno++
	return client.authenticator.doer.Do(req)
}

var _ graphql.Doer = (*SequentialAuthenticator)(nil)

func GetGqlClient(config Config, addr NodeAddress) (graphql.Client, *int, error) {
	authenticator := NewAuthenticator(config.Sk, http.DefaultClient)
	if entry, has := config.NodeData[addr]; has {
		return entry.Client, entry.LastStatusCode, nil
	}
	url := "http://" + string(addr) + "/graphql"
	authClient := graphql.NewClient(url, authenticator)
	resp, err := auth(config.Ctx, authClient)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to authorize client %s: %v", addr, err)
	}
	seqAuthenticator := NewSequentialAuthenticator(resp.Auth.ServerUuid, resp.Auth.SignerSequenceNumber, authenticator)
	client := graphql.NewClient(url, seqAuthenticator)
	config.NodeData[addr] = NodeEntry{
		Client:          client,
		Libp2pPort:      resp.Auth.Libp2pPort,
		PeerId:          resp.Auth.PeerId,
		IsBlockProducer: resp.Auth.IsBlockProducer,
		LastStatusCode:  &authenticator.doer.LastStatusCode,
	}
	return client, &authenticator.doer.LastStatusCode, nil
}

func wrapGqlRequest(config Config, nodeAddress NodeAddress, perform func(client graphql.Client) (any, error)) (any, error) {
	client, lastCode, err := GetGqlClient(config, nodeAddress)
	if err != nil {
		return "", fmt.Errorf("failed to create a client for %s: %v", nodeAddress, err)
	}
	resp, err := perform(client)
	if err != nil && *lastCode == 412 {
		config.Log.Infof("received sequencing error code (412), retrying request to %s, error: %v", nodeAddress, err)
		delete(config.NodeData, nodeAddress)
		var client graphql.Client
		client, _, err = GetGqlClient(config, nodeAddress)
		if err != nil {
			return "", fmt.Errorf("failed to create a replacement client for %s: %v", nodeAddress, err)
		}
		resp, err = perform(client)
	}
	return resp, err
}

func SchedulePaymentsGql(config Config, nodeAddress NodeAddress, input PaymentsDetails) (string, error) {
	resp, err := wrapGqlRequest(config, nodeAddress, func(client graphql.Client) (any, error) {
		return schedulePayments(config.Ctx, client, input)
	})
	if err != nil {
		return "", fmt.Errorf("error scheduling payments to %s: %v", nodeAddress, err)
	}
	return resp.(*schedulePaymentsResponse).SchedulePayments, nil
}

func StopTransactionsGql(config Config, nodeAddress NodeAddress, handle string) (string, error) {
	resp, err := wrapGqlRequest(config, nodeAddress, func(client graphql.Client) (any, error) {
		return stopScheduledTransactions(config.Ctx, client, handle)
	})
	if err != nil {
		return "", fmt.Errorf("error stoping transactions at %s on %s: %v", handle, nodeAddress, err)
	}
	return resp.(*stopScheduledTransactionsResponse).StopScheduledTransactions, nil
}

func ScheduleZkappCommands(config Config, nodeAddress NodeAddress, input ZkappCommandsDetails) (string, error) {
	resp, err := wrapGqlRequest(config, nodeAddress, func(client graphql.Client) (any, error) {
		return scheduleZkappCommands(config.Ctx, client, input)
	})
	if err != nil {
		return "", fmt.Errorf("error scheduling zkapp txs to %s: %v", nodeAddress, err)
	}
	return resp.(*scheduleZkappCommandsResponse).ScheduleZkappCommands, nil
}

func SlotsWonGql(config Config, nodeAddress NodeAddress) ([]int, bool, error) {
	resp, err := wrapGqlRequest(config, nodeAddress, func(client graphql.Client) (any, error) {
		if config.NodeData[nodeAddress].IsBlockProducer {
			return slotsWon(config.Ctx, client)
		}
		return nil, nil
	})
	if err != nil {
		return nil, true, fmt.Errorf("failed to get slots for %s: %v", nodeAddress, err)
	}
	if resp == nil {
		return nil, false, nil
	}
	return resp.(*slotsWonResponse).SlotsWon, true, nil
}

func UpdateGatingGql(config Config, nodeAddress NodeAddress, input GatingUpdate) error {
	_, err := wrapGqlRequest(config, nodeAddress, func(client graphql.Client) (any, error) {
		return updateGating(config.Ctx, client, input)
	})
	if err != nil {
		return fmt.Errorf("failed to update gating for %s: %v", nodeAddress, err)
	}
	// TODO do something with resp.UpdateGating?
	return nil
}
