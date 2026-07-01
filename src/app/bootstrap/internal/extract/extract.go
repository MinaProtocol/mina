// Package extract decompresses gzip + tar archives produced by Mina's
// archive-dump pipeline. The dumps land as "<prefix>-YYYY-MM-DD.sql.tar.gz"
// and contain a single "<prefix>-YYYY-MM-DD.sql" file.
package extract

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
)

// TarGz extracts the contents of src (a .tar.gz file) into dstDir and returns
// the list of files written.
//
// Refuses anything that escapes dstDir (path traversal protection).
func TarGz(src, dstDir string) ([]string, error) {
	f, err := os.Open(src)
	if err != nil {
		return nil, fmt.Errorf("open %s: %w", src, err)
	}
	defer f.Close()

	gz, err := gzip.NewReader(f)
	if err != nil {
		return nil, fmt.Errorf("gzip %s: %w", src, err)
	}
	defer gz.Close()

	if err := os.MkdirAll(dstDir, 0o755); err != nil {
		return nil, fmt.Errorf("mkdir %s: %w", dstDir, err)
	}

	tr := tar.NewReader(gz)
	var written []string
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("read tar: %w", err)
		}

		target := filepath.Join(dstDir, hdr.Name)
		if !strings.HasPrefix(target, filepath.Clean(dstDir)+string(os.PathSeparator)) && target != filepath.Clean(dstDir) {
			return nil, fmt.Errorf("tar entry escapes target dir: %s", hdr.Name)
		}

		switch hdr.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, os.FileMode(hdr.Mode)); err != nil {
				return nil, err
			}
		case tar.TypeReg:
			out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, os.FileMode(hdr.Mode))
			if err != nil {
				return nil, err
			}
			if _, err := io.Copy(out, tr); err != nil {
				out.Close()
				return nil, err
			}
			out.Close()
			written = append(written, target)
			slog.Debug("extracted", "file", target, "size", hdr.Size)
		default:
			slog.Debug("skipping non-regular tar entry", "name", hdr.Name, "type", hdr.Typeflag)
		}
	}
	return written, nil
}
