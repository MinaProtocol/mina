package main

import (
	"context"
	. "delegation_backend"
	"net/http"
	"time"

	"cloud.google.com/go/storage"
	logging "github.com/ipfs/go-log/v2"
	"google.golang.org/api/option"
	sheets "google.golang.org/api/sheets/v4"
)

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

	app := new(App)
	app.Log = log
	http.HandleFunc("/", func(rw http.ResponseWriter, r *http.Request) {
		_, _ = rw.Write([]byte("delegation backend service"))
	})
	http.Handle("/v1/submit", app.NewSubmitH())
	client, err1 := storage.NewClient(ctx)
	if err1 != nil {
		log.Fatalf("Error creating Cloud client: %v", err1)
		return
	}
	gctx := GoogleContext{Bucket: client.Bucket(CloudBucketName()), Context: ctx, Log: log}
	app.Save = func(objs ObjectsToSave) {
		gctx.GoogleStorageSave(objs)
	}
	app.Now = func() time.Time { return time.Now() }
	app.SubmitCounter = NewAttemptCounter(REQUESTS_PER_PK_HOURLY)
	sheetsService, err2 := sheets.NewService(ctx, option.WithScopes(sheets.SpreadsheetsReadonlyScope))
	if err2 != nil {
		log.Fatalf("Error creating Sheets service: %v", err2)
		return
	}
	initWl := RetrieveWhitelist(sheetsService, log)
	wlMvar := new(WhitelistMVar)
	wlMvar.Replace(&initWl)
	app.Whitelist = wlMvar
	go func() {
		for {
			wl := RetrieveWhitelist(sheetsService, log)
			wlMvar.Replace(&wl)
			time.Sleep(WHITELIST_REFRESH_INTERVAL)
		}
	}()
	log.Fatal(http.ListenAndServe(DELEGATION_BACKEND_LISTEN_TO, nil))
}
