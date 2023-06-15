package itn_uptime_analyzer

import (
	dg "block_producers_uptime/delegation_backend"
	"context"
	"encoding/json"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/storage"
	logging "github.com/ipfs/go-log/v2"
	"google.golang.org/api/iterator"
)

// This function tries to match the identities with the submission data and if there is a match it appends
// To the uptime array, the length of which determines if the node was up or not
// Length of 47 is enough

func (identity Identity) GetUptime(ctx context.Context, client *storage.Client, log *logging.ZapEventLogger) {

	currentTime := GetCurrentTime()
	currentDateString := currentTime.Format(time.RFC3339)[:10]
	lastExecutionTime := GetLastExecutionTime(currentTime)

	prefixCurrent := strings.Join([]string{"submissions", currentDateString}, "/")
	submissions := client.Bucket(dg.CloudBucketName()).Objects(ctx, &storage.Query{Prefix: prefixCurrent})

	var submissionData dg.submitRequest
	var lastSubmissionDate string
	var lastSubmissionTime time.Time
	var uptime []bool

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

			if (identity["public-key"] == submissionData.Submitter.String()) && (identity["public-ip"] == submissionData.RemoteAddr) {
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

				if (lastSubmissionDate != "") && (currentSubmissionTime.After(lastSubmissionTime.Add(10 * time.Minute))) && (currentSubmissionTime.Before(lastSubmissionTime.Add(20 * time.Minute))) {
					uptime = append(uptime, true)
					lastSubmissionDate = submissionData.CreatedAt
				} else if lastSubmissionDate == "" {
					lastSubmissionDate = submissionData.CreatedAt
				}

			}
			reader.Close()
		}
	}
	identity["uptime"] = strconv.Itoa(len(uptime))
}
