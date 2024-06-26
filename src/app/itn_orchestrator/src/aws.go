package itn_orchestrator

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	logging "github.com/ipfs/go-log/v2"
)

type AwsContext struct {
	Client     *s3.Client
	BucketName *string
	Prefix     string
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

func (config AwsContext) iterateSubmissions(ctx context.Context, log logging.StandardLogger, startAfter string, handleAddress func(MiniMetaToBeSaved)) error {
	resp, err := config.ListObjects(ctx, startAfter, nil)
	if err != nil {
		return err
	}
	for {
		for _, obj := range resp.Contents {
			name := *obj.Key
			r, err := config.ReadObject(ctx, obj.Key)
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
				meta.RemoteAddr = meta.RemoteAddr[:colonIx]
			}
			handleAddress(meta.MiniMetaToBeSaved)
		}
		if resp.IsTruncated {
			resp, err = config.ListObjects(ctx, startAfter, resp.NextContinuationToken)
			if err != nil {
				return err
			}
		} else {
			return nil
		}
	}
}
