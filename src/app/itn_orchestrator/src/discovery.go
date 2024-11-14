package itn_orchestrator

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/Khan/genqlient/graphql"
	logging "github.com/ipfs/go-log/v2"
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
	Limit              int  `json:"limit,omitempty"`
	OnlyBlockProducers bool `json:"onlyBPs,omitempty"`
	NoBlockProducers   bool `json:"noBPs,omitempty"`
	Exactly            bool `json:"exactly,omitempty"`
}

type nodeAddrEntry struct {
	addr  NodeAddress
	entry NodeEntry
	isNew bool
}

type nodeAddrEntriesAndCount struct {
	entries []nodeAddrEntry
	count   int
}

// retryGetURL attempts to retrieve the content of a URL up to maxAttempts times
// with a delay between each retry, then decode received JSON into an array of MiniMetaToBeSaved
func retryGetURL(ctx context.Context, log logging.StandardLogger, url string, maxAttempts int, delay time.Duration) (contents []MiniMetaToBeSaved, err error) {
	// Attempt to get the URL content up to maxAttempts times
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		resp, err := http.Get(url)
		if err == nil {
			var body []byte
			// Read the response body
			body, err = io.ReadAll(resp.Body)
			_ = resp.Body.Close() // Close the response body
			if err == nil {
				err = json.Unmarshal(body, &contents)
			}
			if err == nil {
				break // Exit the loop if successful
			}
		}

		log.Warnf("Attempt %d failed: %v\n", attempt, err)
		if attempt < maxAttempts {
			log.Warnf("Retrying in %v...\n", delay)
			select {
			case <-ctx.Done(): // If the context is cancelled,
				return nil, ctx.Err()
			case <-time.After(delay):
			}
		}
	}
	return
}

func (config *Config) iterateSubmissions(handler func(MiniMetaToBeSaved)) error {
	if config.AwsContext != nil {
		before := time.Now().Add(-15 * time.Minute)
		startAfter := prefixByTime(before)
		return config.AwsContext.iterateSubmissions(config.Ctx, config.Log, startAfter, handler)
	} else {
		submissions, err := retryGetURL(config.Ctx, config.Log, config.OnlineURL, 5, time.Minute)
		if err != nil {
			return err
		}
		for _, meta := range submissions {
			handler(meta)
		}
		return nil
	}
}

func discoverParticipantsDo(config Config, params DiscoveryParams, output func(NodeAddress)) error {
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
			}
			cnt++
		}
		connectedResultChan <- nodeAddrEntriesAndCount{entries: entries, count: cnt}
	}()
	tryToConnect := func(pk string, addr NodeAddress) {
		defer wg.Done()
		entry, err := NewGqlClient(config, addr)
		if err == nil {
			connected <- nodeAddrEntry{addr: addr, entry: *entry, isNew: true}
		} else {
			log.Warnf("Error on auth for %s (%s): %v", addr, pk, err)
		}
	}
	connecting := make(map[NodeAddress]struct{})

	config.iterateSubmissions(func(meta MiniMetaToBeSaved) {
		addr := NodeAddress(meta.RemoteAddr + ":" + strconv.Itoa(int(meta.GraphqlControlPort)))
		if _, has := connecting[addr]; !has {
			connecting[addr] = struct{}{}
			if entry, has := config.NodeData[addr]; has {
				connected <- nodeAddrEntry{addr: addr, entry: entry, isNew: false}
			} else {
				wg.Add(1)
				go tryToConnect(meta.Submitter, addr)
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
