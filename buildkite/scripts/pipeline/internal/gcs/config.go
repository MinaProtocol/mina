package gcs

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	"cloud.google.com/go/storage"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

const (
	PrefixGS    = "gs://"
	PrefixHTTPS = "https://storage.googleapis.com/"
)

// FindLatestConfig finds the latest .gz file with the given GCS URL prefix.
// Expected format: gs://bucket/path/prefix or https://storage.googleapis.com/bucket/path/prefix
func FindLatestConfig(ctx context.Context, urlPrefix string) (string, error) {
	var bucketName, objectPrefix string

	if strings.HasPrefix(urlPrefix, PrefixGS) {
		parts := strings.SplitN(strings.TrimPrefix(urlPrefix, PrefixGS), "/", 2)
		bucketName = parts[0]
		if len(parts) > 1 {
			objectPrefix = parts[1]
		}
	} else if strings.HasPrefix(urlPrefix, PrefixHTTPS) {
		parts := strings.SplitN(strings.TrimPrefix(urlPrefix, PrefixHTTPS), "/", 2)
		bucketName = parts[0]
		if len(parts) > 1 {
			objectPrefix = parts[1]
		}
	} else {
		return "", fmt.Errorf("invalid GCS URL format, expected %s or %s", PrefixGS, PrefixHTTPS)
	}

	fmt.Printf("Searching for latest config in bucket '%s' with prefix '%s'...\n", bucketName, objectPrefix)

	client, err := storage.NewClient(ctx, option.WithoutAuthentication())
	if err != nil {
		return "", fmt.Errorf("failed to create GCS client: %w", err)
	}
	defer client.Close()

	bucket := client.Bucket(bucketName)
	query := &storage.Query{
		Prefix: objectPrefix,
	}

	var objects []*storage.ObjectAttrs
	it := bucket.Objects(ctx, query)
	for {
		attrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return "", fmt.Errorf("failed to list objects: %w", err)
		}

		if strings.HasSuffix(attrs.Name, ".gz") {
			objects = append(objects, attrs)
		}
	}

	if len(objects) == 0 {
		return "", fmt.Errorf("no .gz files found with prefix '%s'", objectPrefix)
	}

	sort.Slice(objects, func(i, j int) bool {
		return objects[i].Name > objects[j].Name
	})

	latestObject := objects[0]
	latestURL := fmt.Sprintf("https://storage.googleapis.com/%s/%s", bucketName, latestObject.Name)

	fmt.Printf("Found latest config: %s (updated: %s)\n", latestObject.Name, latestObject.Updated.Format(time.RFC3339))
	return latestURL, nil
}
