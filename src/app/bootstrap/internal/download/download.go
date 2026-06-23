// Package download fetches objects from public buckets with a progress bar.
//
// Objects are fetched from GCS via cloud.google.com/go/storage (archive dumps
// and precomputed blocks live there).
//
// Authentication for GCS uses option.WithoutAuthentication() since the
// archive-dumps bucket allows anonymous reads. If that ever changes, the
// standard Google SDK auth chain kicks in.
package download

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
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
