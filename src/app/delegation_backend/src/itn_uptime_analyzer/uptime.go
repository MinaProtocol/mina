package itn_uptime_analyzer

import (
	"encoding/json"
	"strings"
	"time"
	"cloud.google.com/go/storage"
	dg "block_producers_uptime/delegation_backend"
	logging "github.com/ipfs/go-log/v2"
	"context"
	"google.golang.org/api/iterator"
	"bytes"
)

func (identity Identity) GetUptime(ctx context.Context, client *storage.Client, log *logging.ZapEventLogger) {

	// currentTime := GetCurrentTime()
	currentTime := time.Date(2023, time.April, 1, 23, 59, 59, 0, time.UTC)
	currentDateString := currentTime.Format(time.RFC3339)[:10]
	lastExecutionTime := GetLastExecutionTime(currentTime)

	prefixCurrent := strings.Join([]string{"submissions", currentDateString}, "/")
	submissions := client.Bucket(dg.CloudBucketName()).Objects(ctx, &storage.Query{Prefix: prefixCurrent})
	
	var submissionData dg.MetaToBeSaved
	var lastSubmissionDate string
	var lastSubmissionTime time.Time
	var uptime bytes.Buffer

	for {
		obj, err := submissions.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Fatalf("Failed to iterate over objects: %v\n", err)
		}

		// Convert time of submission to time object for filtering

		submissionTimeString := obj.Name[23:43]
		submissionTime, err := time.Parse(time.RFC3339, submissionTimeString)
		if err != nil {
			log.Fatalf("Error parsing time: %v\n", err)
		}

		if (submissionTime.After(lastExecutionTime)) && (submissionTime.Before(currentTime)) {
			reader, err := client.Bucket(dg.CloudBucketName()).Object(obj.Name).NewReader(ctx)
			if err != nil {
				log.Fatalf("Error getting creating reader for json: %v\n", err)
			}
				
			decoder := json.NewDecoder(reader)

			err = decoder.Decode(&submissionData)
			if err != nil {
				log.Fatalf("Error converting json to string: %v\n", err)
			}	

			if (identity["public-key"] == submissionData.Submitter.String()) && (identity["public-ip"] == "45.45.45.45") { //submissionData.RemoteAddr
				if lastSubmissionDate != "" {
					lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionDate)
					if err != nil {
						log.Fatalf("Error parsing time: %v\n", err)
					}
				}

				currentSubmissionTime, err := time.Parse(time.RFC3339, submissionData.CreatedAt)
				if err != nil {
					log.Fatalf("Error parsing time: %v", err)
				}
				
				if (lastSubmissionDate != "") && (currentSubmissionTime.After(lastSubmissionTime.Add(14 * time.Minute))) && (currentSubmissionTime.Before(lastSubmissionTime.Add(16 * time.Minute))) {
					uptime.WriteString("1")
					lastSubmissionDate = submissionData.CreatedAt
				} else if lastSubmissionDate == "" {
					lastSubmissionDate = submissionData.CreatedAt
				}

			}
			reader.Close()
		}
	}
	identity["uptime"] = uptime.String()

}