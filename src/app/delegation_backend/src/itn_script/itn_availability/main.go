package main

import (
	logging "github.com/ipfs/go-log/v2"
	// "cloud.google.com/go/storage"
	// sheets "google.golang.org/api/sheets/v4"
	// "google.golang.org/api/option"
	"fmt"
	"time"
	"strings"
	"strconv"
	// "context"
	. "itn_script"
	"delegation_backend"
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

	// ctx := context.Background()
	app := new(App)
	app.Log = log

	// Get current date

	currentTime := time.Now()
	currentDateString := currentTime.Format(time.RFC3339)
	fmt.Println(currentDateString)

	// Get last execution of application

	hourIndex := strings.Index(currentDateString, strconv.Itoa(currentTime.Hour()))
	currentHour, err := strconv.Atoi(currentDateString[hourIndex:hourIndex+2])

	var lastExecutionHour string

	if err != nil {
			log.Fatalf("Error getting current hour: %v", err)
	}
	if currentHour < 12 {
		lastExecutionHour = strconv.Itoa(24 + (currentHour - 12))
		fmt.Println("Last exec hour is: ", lastExecutionHour)
	} else {
		if len(strconv.Itoa(currentHour - 12)) == 1 {
			lastExecutionHour = 	strings.Join([]string{"0", strconv.Itoa(currentHour - 12)}, "")
			fmt.Println(lastExecutionHour)
		} else {
		lastExecutionHour = strconv.Itoa(currentHour - 12)
		fmt.Println(lastExecutionHour)
		}
	}

	lastExecutionTime := strings.Join([]string{currentDateString[:hourIndex], lastExecutionHour, currentDateString[hourIndex+2:]}, "")
	fmt.Println(lastExecutionTime)

	// Create Google Cloud client

	client, err1 := storage.NewClient(ctx)
	if err1 != nil {
		log.Fatalf("Error creating Cloud client: %v", err1)
		return
	}

	// bucket := client.Bucket(CloudBucketName())

	// TODO Calculate current time minus 12 hours

	// Create a query object for filtering the entries from the last 12 hours

	// submissions := client.Bucket(CloudBucketName()).Object("submissions")
	// blocks := client.Bucket(CloudBucketName()).Object("blocks")

}