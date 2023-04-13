package itn_orchestrator

import (
	"context"
	"crypto/ed25519"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/storage"
	"github.com/Khan/genqlient/graphql"
	"google.golang.org/api/iterator"
)

func prefixByTime(t time.Time) string {
	tStr := t.UTC().Format(time.RFC3339)
	dStr := t.UTC().Format(time.DateOnly)
	return strings.Join([]string{"submissions", dStr, tStr}, "/")
}

type NodeAddress string

type Node struct {
	Address NodeAddress
	Client  graphql.Client
}

type DiscoveryParams struct {
	OffsetMin int
	Limit     int
}

type GetGqlClientF = func(context.Context, NodeAddress) (graphql.Client, error)

func GetGqlClient(sk ed25519.PrivateKey, cache map[NodeAddress]graphql.Client) GetGqlClientF {
	authenticator := NewAuthenticator(sk, http.DefaultClient)
	return func(ctx context.Context, addr NodeAddress) (graphql.Client, error) {
		if client, has := cache[addr]; has {
			return client, nil
		}
		url := "http://" + string(addr) + "/graphql"
		authClient := graphql.NewClient(url, authenticator)
		uuid, seqno, err := Auth(ctx, authClient)
		if err != nil {
			return nil, fmt.Errorf("failed to authorize client %s: %v", addr, err)
		}
		seqAuthenticator := NewSequentialAuthenticator(uuid, seqno, authenticator)
		return graphql.NewClient(url, seqAuthenticator), nil
	}
}

func DiscoverParticipants(config Config, params DiscoveryParams, output func(NodeAddress)) error {
	before := time.Now().Add(-time.Duration(params.OffsetMin) * time.Minute)
	query := &storage.Query{StartOffset: prefixByTime(before)}
	log := config.Log
	ctx := config.Ctx
	it := config.UptimeBucket.Objects(ctx, query)
	cache := make(map[NodeAddress]struct{})
	for {
		attrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return err
		}
		r, err := config.UptimeBucket.Object(attrs.Name).NewReader(ctx)
		if err != nil {
			log.Errorf("Error reading submission %s: %v", attrs.Name, err)
			continue
		}
		var meta MetaToBeSaved
		d := json.NewDecoder(r)
		err = d.Decode(&meta)
		if err != nil {
			log.Errorf("Error decoding submission %s: %v", attrs.Name, err)
			continue
		}
		colonIx := strings.IndexRune(meta.RemoteAddr, ':')
		if colonIx < 0 {
			return fmt.Errorf("wrong remote address in submission %s: %s", attrs.Name, meta.RemoteAddr)
		}
		addr := NodeAddress(meta.RemoteAddr[:colonIx] + ":" + strconv.Itoa(int(meta.GraphqlControlPort)))
		if _, has := cache[addr]; has {
			continue
		}
		_, err = config.GetGqlClient(ctx, addr)
		if err != nil {
			log.Errorf("Error on auth for %s: %v", addr, err)
			continue
		}
		cache[addr] = struct{}{}
		output(addr)
		if len(cache) >= params.Limit {
			break
		}
	}
	return nil
}

type DiscoverParticipantsAction struct{}

func (DiscoverParticipantsAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params DiscoveryParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return DiscoverParticipants(config, params, func(addr NodeAddress) {
		output("participant", addr, true, false)
	})
}

var _ Action = DiscoverParticipantsAction{}
