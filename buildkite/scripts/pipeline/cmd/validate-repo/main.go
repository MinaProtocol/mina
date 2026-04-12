// validate-repo validates and optionally fixes a Mina Debian repository.
//
// Beyond deb-s3 verify (which only checks file existence), this tool
// downloads the Packages manifest and verifies that the SHA256 hashes
// and file sizes match the actual objects in S3. This catches the
// stale-manifest problem that --force-upload-debians can cause.
//
// Usage:
//
//	validate-repo --repo nightly.apt.packages.minaprotocol.com --channel develop
//	validate-repo --repo nightly.apt.packages.minaprotocol.com --channel develop --fix
//	validate-repo --repo packages.o1test.net --channel stable --codenames noble,bookworm
package main

import (
	"bufio"
	"crypto/sha256"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

const (
	defaultRepo      = "nightly.apt.packages.minaprotocol.com"
	defaultCodenames = "noble,bookworm"
	defaultArchs     = "amd64,arm64"
	defaultS3Region  = "us-west-2"
)

// pkgEntry represents one package entry from a Packages manifest.
type pkgEntry struct {
	Package  string
	Version  string
	Filename string
	Size     int64
	SHA256   string
}

// parsePackagesFile parses a Debian Packages file into entries.
func parsePackagesFile(r io.Reader) []pkgEntry {
	var entries []pkgEntry
	var current pkgEntry
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			if current.Filename != "" {
				entries = append(entries, current)
			}
			current = pkgEntry{}
			continue
		}
		if k, v, ok := strings.Cut(line, ": "); ok {
			switch k {
			case "Package":
				current.Package = v
			case "Version":
				current.Version = v
			case "Filename":
				current.Filename = v
			case "Size":
				current.Size, _ = strconv.ParseInt(v, 10, 64)
			case "SHA256":
				current.SHA256 = v
			}
		}
	}
	if current.Filename != "" {
		entries = append(entries, current)
	}
	return entries
}

// verifyHashes downloads the Packages manifest from the repo HTTPS endpoint,
// then checks each package's actual size and SHA256 against what the manifest claims.
func verifyHashes(repo, codename, channel, arch string) (mismatches []string, err error) {
	// Fetch the Packages file
	url := fmt.Sprintf("https://%s/dists/%s/%s/binary-%s/Packages", repo, codename, channel, arch)
	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch %s: %w", url, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("HTTP %d fetching %s", resp.StatusCode, url)
	}

	entries := parsePackagesFile(resp.Body)
	if len(entries) == 0 {
		return nil, fmt.Errorf("no packages found in %s", url)
	}

	for _, pkg := range entries {
		pkgURL := fmt.Sprintf("https://%s/%s", repo, pkg.Filename)

		// HEAD request to check size without downloading
		headResp, err := http.Head(pkgURL)
		if err != nil {
			mismatches = append(mismatches, fmt.Sprintf("%s %s: fetch error: %v", pkg.Package, pkg.Version, err))
			continue
		}
		headResp.Body.Close()

		if headResp.StatusCode != 200 {
			mismatches = append(mismatches, fmt.Sprintf("%s %s: HTTP %d (file missing?)", pkg.Package, pkg.Version, headResp.StatusCode))
			continue
		}

		actualSize := headResp.ContentLength
		if actualSize >= 0 && actualSize != pkg.Size {
			mismatches = append(mismatches,
				fmt.Sprintf("%s %s: size mismatch (manifest=%d, actual=%d)",
					pkg.Package, pkg.Version, pkg.Size, actualSize))
			continue
		}

		// Full download + SHA256 check
		getResp, err := http.Get(pkgURL)
		if err != nil {
			mismatches = append(mismatches, fmt.Sprintf("%s %s: download error: %v", pkg.Package, pkg.Version, err))
			continue
		}

		hasher := sha256.New()
		written, _ := io.Copy(hasher, getResp.Body)
		getResp.Body.Close()

		actualHash := fmt.Sprintf("%x", hasher.Sum(nil))

		if written != pkg.Size {
			mismatches = append(mismatches,
				fmt.Sprintf("%s %s: size mismatch (manifest=%d, downloaded=%d)",
					pkg.Package, pkg.Version, pkg.Size, written))
		} else if actualHash != pkg.SHA256 {
			mismatches = append(mismatches,
				fmt.Sprintf("%s %s: SHA256 mismatch (manifest=%s, actual=%s)",
					pkg.Package, pkg.Version, pkg.SHA256, actualHash))
		} else {
			fmt.Printf("    ✓ %s %s [%s] OK\n", pkg.Package, pkg.Version, arch)
		}
	}

	return mismatches, nil
}

func main() {
	var (
		repo      = flag.String("repo", defaultRepo, "Debian repository (S3 bucket name)")
		channel   = flag.String("channel", "", "Debian component/channel to validate (required)")
		codenames = flag.String("codenames", defaultCodenames, "Comma-separated codenames")
		archs     = flag.String("archs", defaultArchs, "Comma-separated architectures")
		s3Region  = flag.String("s3-region", defaultS3Region, "AWS S3 region")
		fix       = flag.Bool("fix", false, "Fix broken manifests (deb-s3 verify --fix-manifests)")
		listOnly  = flag.Bool("list", false, "Only list packages, skip verification")
		skipHash  = flag.Bool("skip-hash-check", false, "Skip SHA256 hash verification (only run deb-s3 verify)")
	)

	flag.Parse()

	if *channel == "" {
		fmt.Fprintln(os.Stderr, "Error: --channel is required")
		flag.Usage()
		os.Exit(1)
	}

	codenameArr := strings.Split(*codenames, ",")
	archArr := strings.Split(*archs, ",")

	exitCode := 0

	for _, codename := range codenameArr {
		codename = strings.TrimSpace(codename)

		fmt.Printf("\n%s\n", strings.Repeat("=", 70))
		fmt.Printf("  Repository: %s\n", *repo)
		fmt.Printf("  Channel:    %s\n", *channel)
		fmt.Printf("  Codename:   %s\n", codename)
		fmt.Printf("%s\n\n", strings.Repeat("=", 70))

		// List packages per architecture
		for _, arch := range archArr {
			arch = strings.TrimSpace(arch)
			fmt.Printf("📋 Packages in %s/%s [%s]:\n", codename, *channel, arch)

			listArgs := []string{
				"list",
				"--bucket=" + *repo,
				"--s3-region=" + *s3Region,
				"--codename", codename,
				"--component", *channel,
				"--arch", arch,
			}

			cmd := exec.Command("deb-s3", listArgs...)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				fmt.Fprintf(os.Stderr, "⚠️  deb-s3 list failed for %s/%s/%s: %v\n", codename, *channel, arch, err)
				exitCode = 1
			}
			fmt.Println()
		}

		if *listOnly {
			continue
		}

		// Hash verification: download Packages manifest and check each .deb
		if !*skipHash {
			for _, arch := range archArr {
				arch = strings.TrimSpace(arch)
				fmt.Printf("🔒 Verifying SHA256 hashes for %s/%s [%s]...\n", codename, *channel, arch)

				mismatches, err := verifyHashes(*repo, codename, *channel, arch)
				if err != nil {
					fmt.Fprintf(os.Stderr, "⚠️  Hash verification error for %s/%s/%s: %v\n", codename, *channel, arch, err)
					exitCode = 1
					continue
				}
				if len(mismatches) > 0 {
					fmt.Printf("❌ %d hash mismatch(es) in %s/%s [%s]:\n", len(mismatches), codename, *channel, arch)
					for _, m := range mismatches {
						fmt.Printf("    ✗ %s\n", m)
					}
					exitCode = 1
				} else {
					fmt.Printf("✅ All hashes valid for %s/%s [%s]\n", codename, *channel, arch)
				}
				fmt.Println()
			}
		}

		// deb-s3 verify (manifest structure check)
		fmt.Printf("🔍 Verifying manifest structure for %s/%s...\n", codename, *channel)

		verifyArgs := []string{
			"verify",
			"--bucket=" + *repo,
			"--s3-region=" + *s3Region,
			"--codename=" + codename,
			"--component=" + *channel,
		}
		if *fix {
			verifyArgs = append(verifyArgs, "--fix-manifests")
			fmt.Println("🔧 Fix mode enabled — broken manifests will be repaired.")
		}

		cmd := exec.Command("deb-s3", verifyArgs...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "❌ Manifest verification failed for %s/%s: %v\n", codename, *channel, err)
			if !*fix {
				fmt.Fprintf(os.Stderr, "   Run with --fix to attempt repair.\n")
			}
			exitCode = 1
		} else {
			fmt.Printf("✅ %s/%s manifest structure is valid.\n", codename, *channel)
		}
		fmt.Println()
	}

	if exitCode == 0 {
		fmt.Println("✅ All repositories validated successfully.")
	} else {
		fmt.Println("❌ Some validations failed.")
		if !*fix {
			fmt.Println("   Run with --fix to repair broken manifests.")
		}
	}
	os.Exit(exitCode)
}
