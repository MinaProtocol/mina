// validate-repo validates and optionally fixes a Mina Debian repository.
//
// It uses deb-s3 to list packages and verify repository manifests for
// each codename/component combination. With --fix, broken manifests
// are repaired in-place.
//
// Usage:
//
//	validate-repo --repo nightly.apt.packages.minaprotocol.com --channel develop
//	validate-repo --repo nightly.apt.packages.minaprotocol.com --channel develop --fix
//	validate-repo --repo packages.o1test.net --channel stable --codenames noble,bookworm
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const (
	defaultRepo      = "nightly.apt.packages.minaprotocol.com"
	defaultCodenames = "noble,bookworm"
	defaultArchs     = "amd64,arm64"
	defaultS3Region  = "us-west-2"
)

func main() {
	var (
		repo      = flag.String("repo", defaultRepo, "Debian repository (S3 bucket name)")
		channel   = flag.String("channel", "", "Debian component/channel to validate (required)")
		codenames = flag.String("codenames", defaultCodenames, "Comma-separated codenames")
		archs     = flag.String("archs", defaultArchs, "Comma-separated architectures")
		s3Region  = flag.String("s3-region", defaultS3Region, "AWS S3 region")
		fix       = flag.Bool("fix", false, "Fix broken manifests (deb-s3 verify --fix-manifests)")
		listOnly  = flag.Bool("list", false, "Only list packages, skip verification")
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

		// Verify manifests
		fmt.Printf("🔍 Verifying manifests for %s/%s...\n", codename, *channel)

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
			fmt.Fprintf(os.Stderr, "❌ Verification failed for %s/%s: %v\n", codename, *channel, err)
			if !*fix {
				fmt.Fprintf(os.Stderr, "   Run with --fix to attempt repair.\n")
			}
			exitCode = 1
		} else {
			fmt.Printf("✅ %s/%s manifests are valid.\n", codename, *channel)
		}
		fmt.Println()
	}

	if exitCode == 0 {
		fmt.Println("✅ All repositories validated successfully.")
	} else {
		fmt.Println("❌ Some validations failed.")
	}
	os.Exit(exitCode)
}
