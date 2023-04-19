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

func loadAwsCredentials(filename string, log logging.EventLogger) {
	file, err := os.Open(filename)
	if err != nil {
		log.Errorf("Error loading credentials file: %s", err)
		os.Exit(1)
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	var credentials AwsCredentials
	err = decoder.Decode(&credentials)
	if err != nil {
		log.Errorf("Error loading credentials file: %s", err)
		os.Exit(1)
	}
	os.Setenv("AWS_ACCESS_KEY_ID", credentials.AccessKeyId)
	os.Setenv("AWS_SECRET_ACCESS_KEY", credentials.SecretAccessKey)
}

func loadEnv(log logging.EventLogger) AppConfig {
	var config AppConfig

	configFile := os.Getenv("CONFIG_FILE")
	if configFile != "" {
		file, err := os.Open(configFile)
		if err != nil {
			log.Errorf("Error loading config file: %s", err)
			os.Exit(1)
		}
		defer file.Close()
		decoder := json.NewDecoder(file)
		err = decoder.Decode(&config)
		if err != nil {
			log.Errorf("Error loading config file: %s", err)
			os.Exit(1)
		}
	} else {
		networkName := os.Getenv("CONFIG_NETWORK_NAME")
		if networkName == "" {
			log.Fatal("missing NETWORK_NAME environment variable")
		}

		gsheetId := os.Getenv("CONFIG_GSHEET_ID")
		if gsheetId == "" {
			log.Fatal("missing GSHEET_ID environment variable")
		}

		awsRegion := os.Getenv("CONFIG_AWS_REGION")
		if awsRegion == "" {
			log.Fatal("missing AWS_REGION environment variable")
		}

		awsAccountId := os.Getenv("CONFIG_AWS_ACCOUNT_ID")
		if awsAccountId == "" {
			log.Fatal("missing AWS_ACCOUNT_ID environment variable")
		}

		config = AppConfig{
			NetworkName: networkName,
			GsheetId:    gsheetId,
			Aws: AwsConfig{
				Region:    awsRegion,
				AccountId: awsAccountId,
			},
		}
	}

	awsCredentialsFile := os.Getenv("AWS_CREDENTIALS_FILE")
	if awsCredentialsFile != "" {
		loadAwsCredentials(awsCredentialsFile, log)
	} else {
		if os.Getenv("AWS_ACCESS_KEY_ID") == "" {
			log.Fatal("missing AWS_ACCESS_KEY_ID environment variable")
		}
		if os.Getenv("AWS_SECRET_ACCESS_KEY") == "" {
			log.Fatal("missing AWS_SECRET_ACCESS_KEY environment variable")
		}
	}

	return config
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

	appCfg := loadEnv(log)

	awsCfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(appCfg.Aws.Region))
	if err != nil {
		log.Fatalf("Error loading AWS configuration: %v", err)
	}

	app := new(App)
	app.Log = log
	http.HandleFunc("/", func(rw http.ResponseWriter, r *http.Request) {
		_, _ = rw.Write([]byte("delegation backend service"))
	})
	http.Handle("/v1/submit", app.NewSubmitH())
	client := s3.NewFromConfig(awsCfg)

	awsctx := AwsContext{Client: client, BucketName: aws.String(GetBucketName(appCfg)), Prefix: appCfg.NetworkName, Context: ctx, Log: log}
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
	initWl := RetrieveWhitelist(sheetsService, log, appCfg)
	wlMvar := new(WhitelistMVar)
	wlMvar.Replace(&initWl)
	app.Whitelist = wlMvar
	go func() {
		for {
			wl := RetrieveWhitelist(sheetsService, log, appCfg)
			wlMvar.Replace(&wl)
			time.Sleep(WHITELIST_REFRESH_INTERVAL)
		}
	}()
	log.Fatal(http.ListenAndServe(DELEGATION_BACKEND_LISTEN_TO, nil))
}
