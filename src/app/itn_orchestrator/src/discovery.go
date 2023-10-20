package itn_orchestrator

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
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

func discoverParticipantsDo(config Config, params DiscoveryParams, output func(NodeAddress)) error {
	before := time.Now().Add(-time.Duration(params.OffsetMin) * time.Minute)
	startAfter := prefixByTime(before)
	log := config.Log
	ctx := config.Ctx

	resp, err := config.AwsContext.ListObjects(ctx, startAfter, nil)
	if err != nil {
		return err
	}
	cache := make(map[NodeAddress]struct{})
	for {
		for _, obj := range resp.Contents {
			name := *obj.Key
			r, err := config.AwsContext.ReadObject(ctx, obj.Key)
			if err != nil {
				log.Errorf("Error reading submission %s: %v", name, err)
				continue
			}
			var meta MetaToBeSaved
			d := json.NewDecoder(r.Body)
			err = d.Decode(&meta)
			if err != nil {
				log.Errorf("Error decoding submission %s: %v", name, err)
				continue
			}
			colonIx := strings.IndexRune(meta.RemoteAddr, ':')
			if colonIx < 0 {
				return fmt.Errorf("wrong remote address in submission %s: %s", name, meta.RemoteAddr)
			}
			addr := NodeAddress(meta.RemoteAddr[:colonIx] + ":" + strconv.Itoa(int(meta.GraphqlControlPort)))
			if _, has := cache[addr]; has {
				continue
			}
			_, _, err = GetGqlClient(config, addr)
			if err != nil {
				log.Errorf("Error on auth for %s: %v", addr, err)
				continue
			}
			if config.NodeData[addr].IsBlockProducer && params.NoBlockProducers {
				continue
			}
			if !config.NodeData[addr].IsBlockProducer && params.OnlyBlockProducers {
				continue
			}
			cache[addr] = struct{}{}
			output(addr)
			if params.Limit > 0 && len(cache) >= params.Limit {
				break
			}
		}
		if resp.IsTruncated {
			resp, err = config.AwsContext.ListObjects(ctx, startAfter, resp.NextContinuationToken)
			if err != nil {
				return err
			}
		} else {
			break
		}
	}
	if len(cache) != params.Limit && params.Exactly {
		return errors.New("failed to discover the exact number of nodes")
	}
	if len(cache) == 0 {
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
