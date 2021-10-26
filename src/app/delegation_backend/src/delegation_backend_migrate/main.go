package main

// This utility migrates from old bucket format to the new one

import (
	"context"
	dg "delegation_backend"
	"encoding/json"
	"fmt"
	"strings"

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
	SubmittedAt string     `json:"submitted_at"`
	PeerId      string     `json:"peer_id"`
	SnarkWork   *dg.Base64 `json:"snark_work,omitempty"`
	RemoteAddr  string     `json:"remote_addr"`
}

func main() {
	logging.SetupLogging(logging.Config{
		Format: logging.JSONOutput,
		Stderr: true,
		Stdout: false,
		Level:  logging.LevelDebug,
		File:   "",
	})
	log := logging.Logger("delegation backend")
	log.Infof("delegation backend has the following logging subsystems active: %v", logging.GetSubsystems())

	ctx := context.Background()

	client, err1 := storage.NewClient(ctx)
	if err1 != nil {
		log.Fatalf("Error creating Cloud client: %v", err1)
		return
	}
	gctx := dg.GoogleContext{Bucket: client.Bucket(dg.CloudBucketName()), Context: ctx, Log: log}
	prefix := "submissions/"
	suffix := ".json"
	q := storage.Query{Prefix: prefix}
	lst := gctx.Bucket.Objects(ctx, &q)
	objAttrs, err := lst.Next()
	for ; err == nil; objAttrs, err = lst.Next() {
		fullName := objAttrs.Name
		var parts []string
		if strings.HasSuffix(fullName, suffix) {
			name := fullName[:len(fullName)-len(suffix)][len(prefix):]
			parts = strings.Split(name, "/")
		}
		if len(parts) != 3 {
			log.Warnf("Malformed submission name: %s", fullName)
			continue
		}
		log.Debug("Processing", fullName)
		pkStr := parts[0]
		blockHashStr := parts[1]
		createdAtStr := parts[2]
		var oldMeta oldMeta
		{
			reader, err := gctx.Bucket.Object(fullName).NewReader(ctx)
			if err == nil {
				decoder := json.NewDecoder(reader)
				err = decoder.Decode(&oldMeta)
			}
			if err != nil {
				log.Warnf("Malformed submission file %s: %v", fullName, err)
				continue
			}
		}
		pk, err := readOldPk(pkStr)
		if err != nil {
			log.Warnf("Malformed pk in %s: %v", fullName, err)
			continue
		}
		pathsNew := dg.MakePathsImpl(oldMeta.SubmittedAt, blockHashStr, pk)
		newMetaPath := pathsNew.Meta
		newMeta := dg.MetaToBeSaved{
			CreatedAt:  createdAtStr,
			PeerId:     oldMeta.PeerId,
			RemoteAddr: oldMeta.RemoteAddr,
			SnarkWork:  oldMeta.SnarkWork,
			Submitter:  pk,
			BlockHash:  blockHashStr,
		}
		newMetaBytes, err1 := json.Marshal(newMeta)
		if err1 != nil {
			log.Errorf("Error while marshaling JSON for %s: %v", fullName, err)
			continue
		}
		gctx.GoogleStorageSave(dg.ObjectsToSave{newMetaPath: newMetaBytes})
	}
	if err != iterator.Done {
		log.Fatalf("Error while iteration through objects: %v", err)
		return
	}
}
