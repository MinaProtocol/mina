package main

import (
	dg "block_producers_uptime/delegation_backend"
	itn "block_producers_uptime/itn_uptime_analyzer"
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go/aws"
	logging "github.com/ipfs/go-log/v2"
	"google.golang.org/api/sheets/v4"
)

func main() {

	// Get the time of execution
	currentTime := itn.GetCurrentTime()

	// Set up sync period of type int representing minutes
	syncPeriod := 15

	// Set up execution interval type int representing hours
	executionInterval := 12

	// Setting up logging for application

	logging.SetupLogging(logging.Config{
		Format: logging.JSONOutput,
		Stderr: true,
		Stdout: false,
		Level:  logging.LevelDebug,
		File:   "",
	})
	log := logging.Logger("itn availability script")
	log.Infof("itn availability script has the following logging subsystems active: %v", logging.GetSubsystems())

	// Empty context object and initializing memory for application

	ctx := context.Background()

	appCfg := itn.LoadEnv(log)

	awsCfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(appCfg.Aws.Region))
	if err != nil {
		log.Fatalf("Error loading AWS configuration: %v", err)
	}

	app := new(dg.App)
	app.Log = log
	client := s3.NewFromConfig(awsCfg)

	awsctx := dg.AwsContext{Client: client, BucketName: aws.String(itn.GetBucketName(appCfg)), Prefix: appCfg.NetworkName, Context: ctx, Log: log}

	// Create Google Cloud client

	sheetsService, err := sheets.NewService(ctx)
	if err != nil {
		log.Fatalf("Error creating Sheets service: %v", err)
	}

	sheetTitle, err := itn.IdentifyWeek(appCfg, sheetsService, log, currentTime)
	if err != nil {
		log.Fatalf("Error identifying week: %v", err)
	}

	identities := itn.CreateIdentities(appCfg, sheetsService, awsctx, log, sheetTitle, currentTime, syncPeriod)

	// Go over identities and calculate uptime

	for _, identity := range identities {
		if itn.IsSyncPeriodEnough(currentTime, syncPeriod) {
			identity.GetUptimeOfTwoDays(appCfg, sheetsService, awsctx, log, sheetTitle, currentTime, syncPeriod, executionInterval)
		} else {
			identity.GetUptimeOfToday(appCfg, sheetsService, awsctx, log, sheetTitle, currentTime, syncPeriod, executionInterval)
		}

		exactMatch, rowIndex, firstEmptyRow := identity.GetCell(appCfg, sheetsService, log, sheetTitle)

		if exactMatch {
			identity.AppendUptime(appCfg, sheetsService, log, sheetTitle, rowIndex)
			fmt.Println("Added exact match")
		} else if (!exactMatch) && (rowIndex == 0) {
			identity.AppendNext(appCfg, sheetsService, log, sheetTitle)
			identity.AppendUptime(appCfg, sheetsService, log, sheetTitle, firstEmptyRow)
		} else if (!exactMatch) && (rowIndex != 0) {
			identity.InsertBelow(appCfg, sheetsService, log, sheetTitle, rowIndex)
			identity.AppendUptime(appCfg, sheetsService, log, sheetTitle, rowIndex+1)
		}
	}

	itn.MarkExecution(appCfg, sheetsService, log, sheetTitle, currentTime, syncPeriod)

}
