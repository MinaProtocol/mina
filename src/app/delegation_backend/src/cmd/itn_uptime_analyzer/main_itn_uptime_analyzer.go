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
	"io/ioutil"
	"encoding/json"
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

	// Create identity struct TODO move this to itn_uptime_analyzer package

	// type NodeIdentity struct {
	// 	PubKey string
	// 	IP string
	// 	// GraphQLPort int
	// }

	var identities map[string]interface{}

	// Empty context object and initializing memory for application

	ctx := context.Background()
	app := new(dg.App)
	app.Log = log

	// Get current time and date

	// currentTime := itn.GetCurrentTime()
	currentTime := time.Date(2023, time.April, 3, 23, 59, 0, 0, time.UTC)
	currentDateString := currentTime.Format(time.RFC3339)[:10]
	fmt.Println(currentTime.Format(time.RFC3339))
	fmt.Println(currentDateString)

	// Get last execution of application

	lastExecutionTime := itn.GetLastExecutionTime(currentTime)
	lastExecutionDateString := lastExecutionTime.Format(time.RFC3339)[:10]
	fmt.Println(lastExecutionDateString)
	fmt.Println(lastExecutionTime.Format(time.RFC3339))
	// Create Google Cloud client

	client, err1 := storage.NewClient(ctx)
	if err1 != nil {
		log.Fatalf("Error creating Cloud client: %v", err1)
		return
	}

	// Create prefix for filtering the entries from the last 12 hours

	prefixCurrent := strings.Join([]string{"submissions", currentDateString}, "/")
	// prefixPast := strings.Join([]string{"submissions", lastExecutionDateString}, "/")

	submissions := client.Bucket(dg.CloudBucketName()).Objects(ctx, &storage.Query{Prefix: prefixCurrent})
	
	for {
		obj, err := submissions.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Fatalf("Failed to iterate over objects: %v", err)
		}
		submissionTimeString := obj.Name[23:43]
		submissionTime, err := time.Parse(time.RFC3339, submissionTimeString)
		if err != nil {
			fmt.Println("Error parsing time:", err)
			return
		}
		if (submissionTime.After(lastExecutionTime)) && (submissionTime.Before(currentTime)) {
			reader, err := client.Bucket(dg.CloudBucketName()).Object(obj.Name).NewReader(ctx)
			if err != nil {
				fmt.Printf("Error getting creating reader for json: %v\n", err)
			}
			contentJSON, err := ioutil.ReadAll(reader)
			if err != nil {
				fmt.Printf("Error reading json: %v\n", err)
			}
			// fmt.Println("Type is %T", contentJSON)
			// fmt.Println(contentJSON)
			err1 = json.Unmarshal(contentJSON, &identities)
			if err1 != nil {
				fmt.Printf("Error converting json to string: %v\n", err1)
			}
			fmt.Println(identities)
		}
	}

	// blocks := client.Bucket(dg.CloudBucketName()).Object("blocks")
	// currentBucket := submissions.Object(currentDateString)

}