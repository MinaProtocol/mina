package extract

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// makeTarGz writes a .tar.gz at path containing the given regular-file entries
// (name -> contents). It does not sanitize names, so callers can craft
// path-traversal entries.
func makeTarGz(t *testing.T, path string, entries map[string]string) {
	t.Helper()
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	for name, contents := range entries {
		hdr := &tar.Header{
			Name:     name,
			Mode:     0o644,
			Size:     int64(len(contents)),
			Typeflag: tar.TypeReg,
		}
		if err := tw.WriteHeader(hdr); err != nil {
			t.Fatalf("write header %q: %v", name, err)
		}
		if _, err := tw.Write([]byte(contents)); err != nil {
			t.Fatalf("write body %q: %v", name, err)
		}
	}
	if err := tw.Close(); err != nil {
		t.Fatalf("close tar: %v", err)
	}
	if err := gz.Close(); err != nil {
		t.Fatalf("close gzip: %v", err)
	}
	if err := os.WriteFile(path, buf.Bytes(), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func TestTarGzExtractsSQLFile(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "dump.tar.gz")
	dst := filepath.Join(dir, "out")

	const sqlName = "mainnet-archive-dump-2026-06-23.sql"
	const sqlBody = "-- mina archive dump\nCREATE TABLE blocks (id int);\n"
	makeTarGz(t, src, map[string]string{sqlName: sqlBody})

	files, err := TarGz(src, dst)
	if err != nil {
		t.Fatalf("TarGz returned error: %v", err)
	}
	if len(files) != 1 {
		t.Fatalf("TarGz wrote %d files, want 1: %v", len(files), files)
	}

	want := filepath.Join(dst, sqlName)
	if files[0] != want {
		t.Errorf("written file = %q, want %q", files[0], want)
	}
	got, err := os.ReadFile(want)
	if err != nil {
		t.Fatalf("reading extracted file: %v", err)
	}
	if string(got) != sqlBody {
		t.Errorf("extracted contents = %q, want %q", string(got), sqlBody)
	}
}

func TestTarGzMultipleFiles(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "multi.tar.gz")
	dst := filepath.Join(dir, "out")

	makeTarGz(t, src, map[string]string{
		"a.sql":      "select 1;",
		"readme.txt": "hello",
	})

	files, err := TarGz(src, dst)
	if err != nil {
		t.Fatalf("TarGz returned error: %v", err)
	}
	if len(files) != 2 {
		t.Fatalf("TarGz wrote %d files, want 2: %v", len(files), files)
	}
}

func TestTarGzRejectsPathTraversal(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "evil.tar.gz")
	dst := filepath.Join(dir, "out")

	makeTarGz(t, src, map[string]string{
		"../escape.sql": "rm -rf /",
	})

	files, err := TarGz(src, dst)
	if err == nil {
		t.Fatalf("TarGz accepted path-traversal entry, wrote: %v", files)
	}
	if !strings.Contains(err.Error(), "escapes target dir") {
		t.Errorf("error = %v, want it to mention escaping target dir", err)
	}
	// Ensure nothing was written outside dst.
	if _, statErr := os.Stat(filepath.Join(dir, "escape.sql")); statErr == nil {
		t.Errorf("path-traversal file was written outside dst")
	}
}

func TestTarGzMissingSource(t *testing.T) {
	dir := t.TempDir()
	_, err := TarGz(filepath.Join(dir, "nope.tar.gz"), filepath.Join(dir, "out"))
	if err == nil {
		t.Fatalf("TarGz on missing source = nil error, want error")
	}
}

func TestTarGzNotGzip(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "plain.tar.gz")
	if err := os.WriteFile(src, []byte("not gzip data"), 0o644); err != nil {
		t.Fatal(err)
	}
	_, err := TarGz(src, filepath.Join(dir, "out"))
	if err == nil {
		t.Fatalf("TarGz on non-gzip source = nil error, want error")
	}
}
