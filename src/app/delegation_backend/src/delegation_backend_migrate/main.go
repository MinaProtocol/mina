package main

// This utility migrates from old bucket format to the new one

import (
	"context"
	. "delegation_backend"
	"encoding/json"
	"strings"

	"cloud.google.com/go/storage"
	logging "github.com/ipfs/go-log/v2"
	"google.golang.org/api/iterator"
)

type oldMeta struct {
	SubmittedAt string  `json:"submitted_at"`
	PeerId      string  `json:"peer_id"`
	SnarkWork   *Base64 `json:"snark_work,omitempty"`
	RemoteAddr  string  `json:"remote_addr"`
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
	gctx := GoogleContext{Bucket: client.Bucket(CloudBucketName()), Context: ctx, Log: log}
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
			log.Warn("Malformed submission name: %s", fullName)
			continue
		}
		log.Debug("Processing %s", fullName)
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
				log.Warn("Malformed submission file %s: %v", fullName, err)
				continue
			}
		}
		pathsNew := MakePathsImpl(oldMeta.SubmittedAt, blockHashStr, pkStr)
		newMetaPath := pathsNew.Meta
		newMeta := MetaToBeSaved{
			CreatedAt:  createdAtStr,
			PeerId:     oldMeta.PeerId,
			RemoteAddr: oldMeta.RemoteAddr,
			SnarkWork:  oldMeta.SnarkWork,
			Submitter:  pkStr,
			BlockHash:  blockHashStr,
		}
		newMetaBytes, err1 := json.Marshal(newMeta)
		if err1 != nil {
			log.Errorf("Error while marshaling JSON for %s: %v", fullName, err)
			continue
		}
		gctx.GoogleStorageSave(ObjectsToSave{newMetaPath: newMetaBytes})
	}
	if err != iterator.Done {
		log.Fatalf("Error while iteration through objects: %v", err)
		return
	}
}
