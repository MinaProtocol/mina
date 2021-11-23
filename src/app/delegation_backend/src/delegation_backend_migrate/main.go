package main

// This utility migrates from old bucket format to the new one

import (
	"bufio"
	"context"
	dg "delegation_backend"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/storage"
	"github.com/btcsuite/btcutil/base58"
	logging "github.com/ipfs/go-log/v2"
	"google.golang.org/api/iterator"
)

func readOldPk(pkOld string) (pk dg.Pk, err error) {
	var bs []byte
	var ver byte
	bs, ver, err = base58.CheckDecode(pkOld)
	if err != nil {
		return
	}
	if dg.BASE58CHECK_VERSION_PK != ver {
		err = fmt.Errorf("unexpected pk version: %d", ver)
		return
	}
	if len(bs) != dg.PK_LENGTH {
		err = fmt.Errorf("unexpected pk length: %d", len(bs))
		return
	}
	copy(pk[:], bs)
	return
}

type oldMeta struct {
	SubmittedAt time.Time  `json:"submitted_at"`
	PeerId      string     `json:"peer_id"`
	SnarkWork   *dg.Base64 `json:"snark_work,omitempty"`
	RemoteAddr  string     `json:"remote_addr"`
}

func process(srcGctx, dstGctx dg.GoogleContext, log logging.StandardLogger, ctx context.Context, fullName string, pk dg.Pk, blockHashStr, createdAtStr string) {
	var oldMeta oldMeta
	{
		reader, err := srcGctx.Bucket.Object(fullName).NewReader(ctx)
		if err == nil {
			decoder := json.NewDecoder(reader)
			err = decoder.Decode(&oldMeta)
		}
		if err != nil {
			log.Warnf("Malformed submission file %s: %v", fullName, err)
			return
		}
	}
	submittedAt := oldMeta.SubmittedAt.UTC().Format(time.RFC3339)
	pathsNew := dg.MakePathsImpl(submittedAt, blockHashStr, pk)
	newMetaPath := pathsNew.Meta
	newMeta := dg.MetaToBeSaved{
		CreatedAt:  createdAtStr,
		PeerId:     oldMeta.PeerId,
		RemoteAddr: oldMeta.RemoteAddr,
		SnarkWork:  oldMeta.SnarkWork,
		Submitter:  pk,
		BlockHash:  blockHashStr,
	}
	newMetaBytes, err := json.Marshal(newMeta)
	if err != nil {
		log.Errorf("Error while marshaling JSON for %s: %v", fullName, err)
		return
	}
	dstGctx.GoogleStorageSave(dg.ObjectsToSave{newMetaPath: newMetaBytes})
}

func main() {
	if len(os.Args) != 4 {
		fmt.Printf("usage: %s <src bucket> <dst bucket> <visited file>\n", os.Args[0])
		os.Exit(1)
	}
	logging.SetupLogging(logging.Config{
		Format: logging.JSONOutput,
		Stderr: true,
		Stdout: false,
		Level:  logging.LevelDebug,
		File:   "",
	})
	log := logging.Logger("delegation backend")
	log.Infof("delegation backend has the following logging subsystems active: %v", logging.GetSubsystems())
	srcBucketName := os.Args[1]
	dstBucketName := os.Args[2]
	visitedFilePath := os.Args[3]
	visited := make(map[string]bool)
	{
		// Read file and insert lines into visited map
		f, err := os.Open(visitedFilePath)
		if err != nil {
			log.Fatal(err)
		}
		defer f.Close()
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			visited[scanner.Text()] = true
		}
	}
	ctx := context.Background()

	client, err1 := storage.NewClient(ctx)
	if err1 != nil {
		log.Fatalf("Error creating Cloud client: %v", err1)
		return
	}
	srcGctx := dg.GoogleContext{Bucket: client.Bucket(srcBucketName), Context: ctx, Log: log}
	dstGctx := dg.GoogleContext{Bucket: client.Bucket(dstBucketName), Context: ctx, Log: log}
	prefix := "submissions/"
	suffix := ".json"
	q := storage.Query{Prefix: prefix}
	lst := srcGctx.Bucket.Objects(ctx, &q)
	objAttrs, err := lst.Next()
	sem := make(chan interface{}, 100)
	for ; err == nil; objAttrs, err = lst.Next() {
		fullName := objAttrs.Name
		if visited[fullName] {
			continue
		}
		var parts []string
		if strings.HasSuffix(fullName, suffix) {
			name := fullName[:len(fullName)-len(suffix)][len(prefix):]
			parts = strings.Split(name, "/")
		}
		if len(parts) != 3 {
			log.Warnf("Malformed submission name: %s", fullName)
			continue
		}
		log.Debug("Processing ", fullName)
		pkStr := parts[0]
		pk, err := readOldPk(pkStr)
		if err != nil {
			log.Warnf("Malformed pk in %s: %v", fullName, err)
			continue
		}
		blockHashStr := parts[1]
		createdAtStr := parts[2]
		select {
		case sem <- nil:
			go func() {
				process(srcGctx, dstGctx, log, ctx, fullName, pk, blockHashStr, createdAtStr)
				<-sem
			}()
		default:
			process(srcGctx, dstGctx, log, ctx, fullName, pk, blockHashStr, createdAtStr)
		}
	}
	if err != iterator.Done {
		log.Fatalf("Error while iteration through objects: %v", err)
		return
	}
}
