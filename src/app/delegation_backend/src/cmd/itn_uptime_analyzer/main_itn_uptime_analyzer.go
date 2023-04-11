package main

import (
	logging "github.com/ipfs/go-log/v2"
	"cloud.google.com/go/storage"
	// sheets "google.golang.org/api/sheets/v4"
	// "google.golang.org/api/option"
	"fmt"
	"strings"
	"time"
	"context"
	itn "block_producers_uptime/itn_uptime_analyzer"
	dg "block_producers_uptime/delegation_backend"
	"google.golang.org/api/iterator"
)

func main (){

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
	app := new(dg.App)
	app.Log = log

	// Get current time and date

	currentTime := itn.GetCurrentTime()
	currentDateString := currentTime.Format(time.RFC3339)[:10]
	fmt.Println(currentTime)
	fmt.Println(currentDateString)

	// Get last execution of application

	lastExecutionTimeString := itn.GetLastExecutionTime(currentTime)
	lastExecutionDateString := lastExecutionTimeString[:10]
	// Create Google Cloud client

	client, err1 := storage.NewClient(ctx)
	if err1 != nil {
		log.Fatalf("Error creating Cloud client: %v", err1)
		return
	}

	// Create prefix for filtering the entries from the last 12 hours

	// prefix := strings.Join([]string{"submissions", currentDateString}, "/")
	prefixCurrent := strings.Join([]string{"submissions", "2023-04-04"}, "/")
	prefixPast := strings.Join([]string{"submissions", lastExecutionDateString}, "/")

	submissions := client.Bucket(dg.CloudBucketName()).Objects(ctx, &storage.Query{Prefix: prefixCurrent})
	
	for {
		obj, err := submissions.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Fatalf("Failed to iterate over objects: %v", err)
		}
		fmt.Println(obj.Name)
	}

	// blocks := client.Bucket(dg.CloudBucketName()).Object("blocks")
	// currentBucket := submissions.Object(currentDateString)

}