package main

import (
	"context"
	. "delegation_backend"
	"encoding/json"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	logging "github.com/ipfs/go-log/v2"
	"google.golang.org/api/option"
	sheets "google.golang.org/api/sheets/v4"
)

func loadAwsConfig(filename string, log logging.EventLogger) AwsConfig {
	// TODO: load config from file
	return AwsConfig{}
}

func loadEnv(log logging.EventLogger) Config {

	var config Config

	configFile := os.Getenv("CONFIG_FILE")
	if configFile != "" {
		file, err := os.Open(configFile)
		if err != nil {
			log.Errorf("Error loading config file: %s", err)
			os.Exit(1)
		}
		defer file.Close()
		decoder := json.NewDecoder(file)
		var config Config
		err = decoder.Decode(&config)
		if err != nil {
			log.Errorf("Error loading config file: %s", err)
			os.Exit(1)
		}
	} else {
		bucketName := os.Getenv("BUCKET_NAME")
		if bucketName == "" {
			log.Fatal("missing BUCKET_NAME environment variable")
		}

		networkName := os.Getenv("NETWORK_NAME")
		if networkName == "" {
			log.Fatal("missing NETWORK_NAME environment variable")
		}

		gsheetId := os.Getenv("GSHEET_ID")
		if gsheetId == "" {
			log.Fatal("missing GSHEET_ID environment variable")
		}

		awsCredentialsFile := os.Getenv("AWS_CREDENTIALS_FILE")
		if awsCredentialsFile == "" {
			log.Fatal("missing AWS_CREDENTIALS_FILE environment variable")
		}
	}

	awsConfig := loadAwsConfig(awsCredentialsFile, log)

	return Config{
		BucketName:  bucketName,
		NetworkName: networkName,
		GsheetId:    gsheetId,
		AwsConfig:   awsConfig,
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

	ctx := context.Background()

	// TODO: get AWS S3 credentials
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("Error creating AWS client: %v", err)
		return
	}

	app := new(App)
	app.Log = log
	http.HandleFunc("/", func(rw http.ResponseWriter, r *http.Request) {
		_, _ = rw.Write([]byte("delegation backend service"))
	})
	http.Handle("/v1/submit", app.NewSubmitH())
	client := s3.NewFromConfig(cfg)
	awsctx := AwsContext{Client: client, BucketName: aws.String(CloudBucketName()), Context: ctx, Log: log}
	app.Save = func(objs ObjectsToSave) {
		awsctx.S3Save(objs)
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

type AwsConfig struct {
	Region   string
	Key      string
	Secret   string
	Endpoint string
}

type Config struct {
	BucketName  string
	NetworkName string
	GsheetId    string
	AwsConfig   AwsConfig
}
