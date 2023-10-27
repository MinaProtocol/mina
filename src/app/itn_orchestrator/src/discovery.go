package itn_orchestrator

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/Khan/genqlient/graphql"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func prefixByTime(t time.Time) string {
	tStr := t.UTC().Format(time.RFC3339)
	dStr := t.UTC().Format(time.DateOnly)
	return strings.Join([]string{"submissions", dStr, tStr}, "/")
}

type Node struct {
	Address NodeAddress
	Client  graphql.Client
}

type DiscoveryParams struct {
	OffsetMin          int  `json:"offsetMin"`
	Limit              int  `json:"limit,omitempty"`
	OnlyBlockProducers bool `json:"onlyBPs,omitempty"`
	NoBlockProducers   bool `json:"noBPs,omitempty"`
	Exactly            bool `json:"exactly,omitempty"`
}

func (awsctx AwsContext) ListObjects(ctx context.Context, startAfter string, continuationToken *string) (*s3.ListObjectsV2Output, error) {
	return awsctx.Client.ListObjectsV2(ctx, &s3.ListObjectsV2Input{
		Bucket:            awsctx.BucketName,
		Prefix:            aws.String(awsctx.Prefix),
		StartAfter:        aws.String(awsctx.Prefix + "/" + startAfter),
		ContinuationToken: continuationToken,
	})
}
func (awsctx AwsContext) ReadObject(ctx context.Context, key *string) (*s3.GetObjectOutput, error) {
	return awsctx.Client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: awsctx.BucketName,
		Key:    key,
	})
}

type nodeAddrEntry struct {
	addr  NodeAddress
	entry NodeEntry
	isNew bool
	pk    string
}

type nodeAddrEntriesAndCount struct {
	entries []nodeAddrEntry
	count   int
}

func iterateSubmissions(config Config, startAfter string, handleAddress func(string, NodeAddress)) error {
	log := config.Log
	ctx := config.Ctx
	resp, err := config.AwsContext.ListObjects(ctx, startAfter, nil)
	if err != nil {
		return err
	}
	for {
		for _, obj := range resp.Contents {
			name := *obj.Key
			r, err := config.AwsContext.ReadObject(ctx, obj.Key)
			if err != nil {
				log.Warnf("Error reading submission %s: %v", name, err)
				continue
			}
			var meta MetaToBeSaved
			d := json.NewDecoder(r.Body)
			err = d.Decode(&meta)
			if err != nil {
				log.Warnf("Error decoding submission %s: %v", name, err)
				continue
			}
			colonIx := strings.IndexRune(meta.RemoteAddr, ':')
			if colonIx < 0 {
				// No port is specified in the address, hence we just take the whole remote address field
				colonIx = len(meta.RemoteAddr)
			}
			addr := NodeAddress(meta.RemoteAddr[:colonIx] + ":" + strconv.Itoa(int(meta.GraphqlControlPort)))
			handleAddress(meta.Submitter, addr)
		}
		if resp.IsTruncated {
			resp, err = config.AwsContext.ListObjects(ctx, startAfter, resp.NextContinuationToken)
			if err != nil {
				return err
			}
		} else {
			return nil
		}
	}
}

func discoverParticipantsDo(config Config, params DiscoveryParams, output func(NodeAddress)) error {
	before := time.Now().Add(-time.Duration(params.OffsetMin) * time.Minute)
	startAfter := prefixByTime(before)
	log := config.Log
	// This function has the following concurrency architecture:
	// 1. There is a goroutine that reads discovered nodes and outputs them, at the end
	//    it returns count of discovered nodes and node entries for new connections
	// 2. There is a goroutine for every node to which we're not connected but which we
	//    found in uptime data
	// 3. Main thread iterates through submissions, eithewr launching a new connection grouroutine (2)
	//    or directly submitting a node to outputting goroutine (1). After iteration main thread waits for
	//    all of connection goroutines (2) to finish and then triggers end of goroutine (1). After that it reads
	//    result of outputting goroutine (1) and updates the connection cache in config.
	var wg sync.WaitGroup
	connected := make(chan nodeAddrEntry)
	connectedResultChan := make(chan nodeAddrEntriesAndCount)
	go func() {
		// Goroutine that is responsible for outputing the participants
		// immediately after they're discovered
		entries := make([]nodeAddrEntry, 0)
		cnt := 0
		for p := range connected {
			if p.isNew {
				entries = append(entries, p)
			}
			if p.entry.IsBlockProducer && params.NoBlockProducers {
				continue
			}
			if !p.entry.IsBlockProducer && params.OnlyBlockProducers {
				continue
			}
			if params.Limit <= 0 || cnt < params.Limit {
				output(p.addr)
				log.Infof("Found participant %s (%s)", p.addr, p.pk)
			}
			cnt++
		}
		connectedResultChan <- nodeAddrEntriesAndCount{entries: entries, count: cnt}
	}()
	tryToConnect := func(pk string, addr NodeAddress) {
		defer wg.Done()
		entry, err := NewGqlClient(config, addr)
		if err == nil {
			connected <- nodeAddrEntry{addr: addr, entry: *entry, isNew: true, pk: pk}
		} else {
			log.Warnf("Error on auth for %s (%s): %v", addr, pk, err)
		}
	}
	connecting := make(map[NodeAddress]struct{})
	iterateSubmissions(config, startAfter, func(pk string, addr NodeAddress) {
		if _, has := connecting[addr]; !has {
			connecting[addr] = struct{}{}
			if entry, has := config.NodeData[addr]; has {
				connected <- nodeAddrEntry{addr: addr, entry: entry, isNew: false, pk: pk}
			} else {
				wg.Add(1)
				go tryToConnect(pk, addr)
			}
		}
	})
	wg.Wait()
	close(connected)
	connectedResult := <-connectedResultChan
	for _, p := range connectedResult.entries {
		config.NodeData[p.addr] = p.entry
	}
	if connectedResult.count < params.Limit && params.Exactly {
		return errors.New("failed to discover the exact number of nodes")
	}
	if connectedResult.count == 0 {
		return errors.New("didn't find any participants")
	}
	return nil
}

func DiscoverParticipants(config Config, params DiscoveryParams, output func(NodeAddress)) (err error) {
	for retryPause := 10; retryPause <= 40; retryPause = retryPause * 2 {
		err = discoverParticipantsDo(config, params, output)
		if err == nil {
			return
		}
		if retryPause <= 20 {
			config.Log.Warnf("Failed to discover participants, retrying in %d minutes: %s", retryPause, err)
			time.Sleep(time.Duration(retryPause) * time.Minute)
		}
	}
	return
}

type DiscoveryAction struct{}

func (DiscoveryAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params DiscoveryParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return DiscoverParticipants(config, params, func(addr NodeAddress) {
		output("participant", addr, true, false)
	})
}

func (DiscoveryAction) Name() string { return "discovery" }

var _ Action = DiscoveryAction{}
