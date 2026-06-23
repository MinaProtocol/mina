// Package download fetches objects from public buckets with a progress bar.
//
// Two transports:
//   - GCS via cloud.google.com/go/storage (archive dumps live here)
//   - HTTP/S3 via net/http (precomputed blocks live in an S3 bucket served
//     publicly over HTTPS — no AWS SDK needed for read-only anonymous access)
//
// Authentication for GCS uses option.WithoutAuthentication() since the
// archive-dumps bucket allows anonymous reads. If that ever changes, the
// standard Google SDK auth chain kicks in.
package download

import (
	"context"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"path"

	"cloud.google.com/go/storage"
	"github.com/schollz/progressbar/v3"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

// GCSObject fetches a single object from a public GCS bucket and writes it
// to dst. If dst already exists with the same size as the remote object, the
// download is skipped (idempotent re-runs are cheap).
func GCSObject(ctx context.Context, bucket, object, dst string) error {
	client, err := storage.NewClient(ctx, option.WithoutAuthentication())
	if err != nil {
		return fmt.Errorf("storage client: %w", err)
	}
	defer client.Close()

	obj := client.Bucket(bucket).Object(object)
	attrs, err := obj.Attrs(ctx)
	if err != nil {
		return fmt.Errorf("stat gs://%s/%s: %w", bucket, object, err)
	}

	if stat, err := os.Stat(dst); err == nil && stat.Size() == attrs.Size {
		slog.Info("destination already matches remote size, skipping download",
			"path", dst, "size", attrs.Size)
		return nil
	}

	reader, err := obj.NewReader(ctx)
	if err != nil {
		return fmt.Errorf("open gs://%s/%s: %w", bucket, object, err)
	}
	defer reader.Close()

	f, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("create %s: %w", dst, err)
	}
	defer f.Close()

	bar := progressbar.DefaultBytes(attrs.Size, fmt.Sprintf("downloading %s", path.Base(object)))
	if _, err := io.Copy(io.MultiWriter(f, bar), reader); err != nil {
		return fmt.Errorf("download: %w", err)
	}
	return nil
}

// ListGCSObjects returns the names of all objects in a GCS bucket matching
// prefix. Bounded by max — pass 0 for no limit.
func ListGCSObjects(ctx context.Context, bucket, prefix string, max int) ([]string, error) {
	client, err := storage.NewClient(ctx, option.WithoutAuthentication())
	if err != nil {
		return nil, fmt.Errorf("storage client: %w", err)
	}
	defer client.Close()

	it := client.Bucket(bucket).Objects(ctx, &storage.Query{Prefix: prefix})
	var names []string
	for {
		attrs, err := it.Next()
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("list gs://%s/%s*: %w", bucket, prefix, err)
		}
		names = append(names, attrs.Name)
		if max > 0 && len(names) >= max {
			break
		}
	}
	return names, nil
}

// HTTPFile fetches a single URL via HTTP GET and writes it to dst. Used for
// the precomputed-blocks S3 bucket which is served publicly over HTTPS.
//
// Skipped if dst already exists at the same Content-Length.
func HTTPFile(ctx context.Context, url, dst string) error {
	headReq, _ := http.NewRequestWithContext(ctx, http.MethodHead, url, nil)
	headResp, err := http.DefaultClient.Do(headReq)
	if err != nil {
		return fmt.Errorf("head %s: %w", url, err)
	}
	headResp.Body.Close()
	if headResp.StatusCode != http.StatusOK {
		return fmt.Errorf("head %s: status %d", url, headResp.StatusCode)
	}
	remoteSize := headResp.ContentLength

	if stat, err := os.Stat(dst); err == nil && remoteSize > 0 && stat.Size() == remoteSize {
		slog.Debug("destination already matches remote size, skipping", "path", dst)
		return nil
	}

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("get %s: %w", url, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("get %s: status %d", url, resp.StatusCode)
	}

	f, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("create %s: %w", dst, err)
	}
	defer f.Close()

	if resp.ContentLength > 0 {
		bar := progressbar.DefaultBytes(resp.ContentLength, fmt.Sprintf("downloading %s", path.Base(dst)))
		_, err = io.Copy(io.MultiWriter(f, bar), resp.Body)
	} else {
		_, err = io.Copy(f, resp.Body)
	}
	if err != nil {
		return fmt.Errorf("download: %w", err)
	}
	return nil
}

// ListS3Bucket queries an anonymous-readable S3 bucket via the list-objects-v2
// XML API and returns matching object keys. baseURL must be the bucket root
// (e.g. https://bucket-name.s3.us-west-2.amazonaws.com/sub-prefix); prefix is
// appended to baseURL's path portion when building the request.
//
// AWS paginates list responses at 1000 keys; this follows continuation tokens
// to the end. Bounded by max — pass 0 for no limit.
func ListS3Bucket(ctx context.Context, baseURL, prefix string, max int) ([]string, error) {
	u, err := url.Parse(baseURL)
	if err != nil {
		return nil, fmt.Errorf("parse baseURL: %w", err)
	}
	// S3 list-objects-v2 takes prefix on the bucket root, so we concat the
	// path portion of baseURL with the caller-supplied prefix.
	fullPrefix := u.Path
	if len(fullPrefix) > 0 && fullPrefix[0] == '/' {
		fullPrefix = fullPrefix[1:]
	}
	if fullPrefix != "" && fullPrefix[len(fullPrefix)-1] != '/' {
		fullPrefix += "/"
	}
	fullPrefix += prefix

	// Rebuild URL with empty path; the bucket-root host is what we query.
	bucketRoot := *u
	bucketRoot.Path = "/"
	bucketRoot.RawQuery = ""

	var keys []string
	var continuationToken string
	for {
		q := url.Values{}
		q.Set("list-type", "2")
		q.Set("prefix", fullPrefix)
		if continuationToken != "" {
			q.Set("continuation-token", continuationToken)
		}
		reqURL := bucketRoot.String() + "?" + q.Encode()

		req, _ := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			return nil, fmt.Errorf("list %s: %w", reqURL, err)
		}
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return nil, fmt.Errorf("read list response: %w", err)
		}
		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("list %s: status %d body=%s", reqURL, resp.StatusCode, string(body))
		}

		var parsed s3ListResult
		if err := xml.Unmarshal(body, &parsed); err != nil {
			return nil, fmt.Errorf("parse list xml: %w", err)
		}
		for _, c := range parsed.Contents {
			keys = append(keys, c.Key)
			if max > 0 && len(keys) >= max {
				return keys, nil
			}
		}
		if !parsed.IsTruncated {
			break
		}
		continuationToken = parsed.NextContinuationToken
		if continuationToken == "" {
			break
		}
	}
	return keys, nil
}

type s3ListResult struct {
	XMLName               xml.Name      `xml:"ListBucketResult"`
	IsTruncated           bool          `xml:"IsTruncated"`
	NextContinuationToken string        `xml:"NextContinuationToken"`
	Contents              []s3ListEntry `xml:"Contents"`
}

type s3ListEntry struct {
	Key string `xml:"Key"`
}
