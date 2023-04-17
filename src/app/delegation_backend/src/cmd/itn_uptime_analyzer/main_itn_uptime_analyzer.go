package main

import (
	logging "github.com/ipfs/go-log/v2"
	"cloud.google.com/go/storage"
	// sheets "google.golang.org/api/sheets/v4"
	// "google.golang.org/api/option"
	"fmt"
	"strings"
	"bytes"
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

	var submissionData map[string]string
	identities := make(map[string]itn.Identity) // Create a map for unique identities

	// Empty context object and initializing memory for application

	ctx := context.Background()
	app := new(dg.App)
	app.Log = log

	// Get current time and date

	// currentTime := itn.GetCurrentTime()
	currentTime := time.Date(2023, time.April, 1, 11, 59, 0, 0, time.UTC)
	currentDateString := currentTime.Format(time.RFC3339)[:10]

	// Get last execution of application

	lastExecutionTime := itn.GetLastExecutionTime(currentTime)
	// lastExecutionDateString := lastExecutionTime.Format(time.RFC3339)[:10]

	fmt.Println(lastExecutionTime)

	// Create Google Cloud client

	client, err1 := storage.NewClient(ctx)
	if err1 != nil {
		log.Fatalf("Error creating Cloud client: %v", err1)
		return
	}

	// Create prefix for filtering the entries from the last 12 hours

	prefixCurrent := strings.Join([]string{"submissions", currentDateString}, "/")

	// Get iterator for objects inside the bucket

	submissions := client.Bucket(dg.CloudBucketName()).Objects(ctx, &storage.Query{Prefix: prefixCurrent})
	
	// Iterate over to find identities

	for {
		obj, err := submissions.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Fatalf("Failed to iterate over objects: %v", err)
		}

		// Convert time of submission to time object for filtering

		submissionTimeString := obj.Name[23:43]
		submissionTime, err := time.Parse(time.RFC3339, submissionTimeString)
		if err != nil {
			fmt.Println("Error parsing time:", err)
			return
		}

		// Check if the submission is in the previous twelve hour window

		if (submissionTime.After(lastExecutionTime)) && (submissionTime.Before(currentTime)) {

			reader, err := client.Bucket(dg.CloudBucketName()).Object(obj.Name).NewReader(ctx)
			if err != nil {
				fmt.Printf("Error getting creating reader for json: %v\n", err)
				return
			}

			contentJSON, err := ioutil.ReadAll(reader)
			if err != nil {
				fmt.Printf("Error reading json: %v\n", err)
				return
			}

			err1 = json.Unmarshal(contentJSON, &submissionData)
			if err1 != nil {
				fmt.Printf("Error converting json to string: %v\n", err1)
				return
			}

			identity := itn.GetIdentity(submissionData["submitter"], "45.45.45.45") // change the IP back to submissionData["remote_addr"] 
			if _, inMap := identities[identity["id"]]; !inMap {
				itn.AddIdentity(identity, identities)
			}

			reader.Close()
		}
	}

	submissions = client.Bucket(dg.CloudBucketName()).Objects(ctx, &storage.Query{Prefix: prefixCurrent})

	for _, identity := range identities {
		var lastSubmissionDate string
		var lastSubmissionTime time.Time
		var uptime bytes.Buffer

		fmt.Println(identity["public-key"])
		fmt.Println(identity["public-ip"])

		for {
			obj, err := submissions.Next()
			if err == iterator.Done {
				break
			}
			if err != nil {
				log.Fatalf("Failed to iterate over objects: %v", err)
			}

		// Convert time of submission to time object for filtering

			submissionTimeString := obj.Name[23:43]
			fmt.Printf("Submission time string: %v\n", submissionTimeString)
			submissionTime, err := time.Parse(time.RFC3339, submissionTimeString)
			fmt.Printf("Submission time: %v\n",submissionTime)
			if err != nil {
				fmt.Println("Error parsing time:", err)
				return
			}

			fmt.Printf("Last exec time: %v\n",lastExecutionTime)

			if (submissionTime.After(lastExecutionTime)) && (submissionTime.Before(currentTime)) {
				fmt.Println("Entered in 12 hour period")
				reader, err := client.Bucket(dg.CloudBucketName()).Object(obj.Name).NewReader(ctx)
				if err != nil {
					fmt.Printf("Error getting creating reader for json: %v\n", err)
					return
				}
				
				contentJSON, err := ioutil.ReadAll(reader)
				if err != nil {
					fmt.Printf("Error reading json: %v\n", err)
					return
				} 

				err1 = json.Unmarshal(contentJSON, &submissionData)
				if err1 != nil {
					fmt.Printf("Error converting json to string: %v\n", err1)
					return
				}
					
				if (identity["public-key"] == submissionData["submitter"]) && (identity["public-ip"] == submissionData["remote_addr"]) {
					if lastSubmissionDate != "" {
						lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionDate)
						fmt.Println(lastSubmissionTime)
						if err != nil {
							fmt.Println("Error parsing time:", err)
							return
						}	
					}

					currentSubmissionTime, err := time.Parse(time.RFC3339, submissionData["created_at"])
					fmt.Println(currentSubmissionTime)
					if err != nil {
						fmt.Println("Error parsing time:", err)
						return
					}
					
					if (lastSubmissionDate != "") && (currentSubmissionTime.After(lastSubmissionTime.Add(14 * time.Minute))) && (currentSubmissionTime.Before(lastSubmissionTime.Add(16 * time.Minute))) {
						uptime.WriteString("1")
						fmt.Println("Current identity is up")
						
					} else if lastSubmissionDate == "" {
						fmt.Println("This is the first submission")
					}

					lastSubmissionDate = submissionData["created_at"]

				}
				reader.Close()
			}
		}
		identity["uptime"] = uptime.String()
		fmt.Println(identity)
		fmt.Println(len(identity["uptime"]))
	}

}