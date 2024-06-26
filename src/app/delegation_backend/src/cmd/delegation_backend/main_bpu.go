package main

import (
	. "block_producers_uptime/delegation_backend"
	"context"
	"net/http"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	logging "github.com/ipfs/go-log/v2"
	"google.golang.org/api/option"
	sheets "google.golang.org/api/sheets/v4"
)

func initAws(cfg *AwsConfig, ctx context.Context, log logging.StandardLogger) AppSaveFunc {
	awsCfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(cfg.Region))
	if err != nil {
		log.Fatalf("Error loading AWS configuration: %v", err)
	}
	client := s3.NewFromConfig(awsCfg)

	awsctx := AwsContext{Client: client, BucketName: aws.String(cfg.GetBucketName()), Prefix: cfg.Prefix, Context: ctx, Log: log}
	return func(submittedAt time.Time, meta MetaToBeSaved, blockHash BlockDataHash, submitter Pk, blockData []byte) error {
		toSave, err := ToObjectsToSave(submittedAt, meta, blockHash, submitter, blockData)
		if err != nil {
			return err
		}
		awsctx.S3Save(toSave)
		return nil
	}
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

	app := new(App)
	app.Log = log
	http.HandleFunc("/", func(rw http.ResponseWriter, r *http.Request) {
		_, _ = rw.Write([]byte("delegation backend service"))
	})
	http.Handle("/v1/submit", app.NewSubmitH())

	ctx := context.Background()

	appCfg := LoadEnv(log)

	if appCfg.InMemory {
		inMemStorage := NewInMemoryStorage(log)
		app.Save = inMemStorage.Save
		http.Handle("/v1/online", inMemStorage)
	} else {
		app.Save = initAws(appCfg.Aws, ctx, log)
	}

	app.Now = func() time.Time { return time.Now() }
	app.SubmitCounter = NewAttemptCounter(REQUESTS_PER_PK_HOURLY)

	whitelist := appCfg.Whitelist
	app.Whitelist = new(WhitelistMVar)
	if len(whitelist) > 0 {
		wl := make(Whitelist)
		for _, pkStr := range whitelist {
			var pk Pk
			err := StringToPk(&pk, pkStr)
			if err == nil {
				wl[pk] = struct{}{}
			}
		}
		app.Whitelist.Replace(wl)
	} else {
		sheetsService, err2 := sheets.NewService(ctx, option.WithScopes(sheets.SpreadsheetsReadonlyScope))
		if err2 != nil {
			log.Fatalf("Error creating Sheets service: %v", err2)
		}
		initWl := RetrieveWhitelist(sheetsService, log, appCfg.GsheetId)
		app.Whitelist.Replace(initWl)
		go func() {
			for {
				wl := RetrieveWhitelist(sheetsService, log, appCfg.GsheetId)
				app.Whitelist.Replace(wl)
				time.Sleep(WHITELIST_REFRESH_INTERVAL)
			}
		}()
	}
	log.Fatal(http.ListenAndServe(DELEGATION_BACKEND_LISTEN_TO, nil))
}
