package main

import (
	"cloud.google.com/go/storage"
	"context"
	logging "github/ipfs/go-log/v2"
	"google.golang.org/api/option"
	"net/http"
	. "node_status_collection_backend"
	"time"
)

func main() {
	logging.SetupLogging(logging.Config{
		Format: logging.JSONOutput,
		Stderr: true,
		Stdout: false,
		Level:  logging.LevelDebug,
		File:   "",
	})
	log := logging.Logger("node status collection backend")
	log.Infof("node status collection backend has the following logging subsystems active: %v", logging.GetSubsystems())

	ctx := context.Background()

	app := new(App)
	app.Log = log
	http.Handle("/v1/submit", app.NewSubmitH())
	client, err1 := storage.NewClient(ctx)
	if err1 != nil {
		log.Fatalf("Error  creating Cloud client: %v", err1)
		return
	}
	gctx := GoogleContext{client.Bucket(CLOUD_BUCKET_NAME), ctx, log}
	app.Save = func(objs ObjectsToSave) {
		gctx.GoogleStorageSave(objs)
	}
	app.Now = func() time.Time { return time.Now() }
	log.Fatal(http.ListenAndServe(NODE_STATUS_COLLECTION_BACKEND_LISTEN_TO, nil))
}
