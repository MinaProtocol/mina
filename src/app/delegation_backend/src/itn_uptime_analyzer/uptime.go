package itn_uptime_analyzer

import (
	dg "block_producers_uptime/delegation_backend"
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/s3"
	logging "github.com/ipfs/go-log/v2"
	sheets "google.golang.org/api/sheets/v4"
)

// This function tries to match the identities with the submission data and if there is a match it appends
// To the uptime array, the length of which determines if the node was up or not
// Length of 47 is enough

func (identity Identity) GetUptime(config AppConfig, sheet *sheets.Service, ctx dg.AwsContext, log *logging.ZapEventLogger, sheetTitle string) {

	currentTime := GetCurrentTime()
	currentDate := currentTime.Format("2006-01-02")
	lastExecutionTime := GetLastExecutionTime(config, sheet, log, sheetTitle)

	prefixCurrent := strings.Join([]string{ctx.Prefix, "submissions", currentDate}, "/")

	input := &s3.ListObjectsV2Input{
		Bucket: ctx.BucketName,
		Prefix: &prefixCurrent,
	}

	paginator := s3.NewListObjectsV2Paginator(ctx.Client, input)

	var submissionData dg.MetaToBeSaved
	var lastSubmissionDate string
	var lastSubmissionTime time.Time
	var uptime []bool

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx.Context)
		if err != nil {
			log.Fatalf("Getting next page of paginator (BPU bucket): %v\n", err)
		}

		for _, obj := range page.Contents {

			// Convert time of submission to time object for filtering

			submissionTime, err := time.Parse(time.RFC3339, (*obj.Key)[32:52])
			if err != nil {
				log.Fatalf("Error parsing time: %v\n", err)
			}

			if (submissionTime.After(lastExecutionTime)) && (submissionTime.Before(currentTime)) {

				objHandle, err := ctx.Client.GetObject(ctx.Context, &s3.GetObjectInput{
					Bucket: ctx.BucketName,
					Key:    obj.Key,
				})

				if err != nil {
					log.Fatalf("Error getting object from bucket: %v\n", err)
				}

				defer objHandle.Body.Close()

				objContents, err := io.ReadAll(objHandle.Body)
				if err != nil {
					log.Fatalf("Error getting creating reader for json: %v\n", err)
				}

				err = json.Unmarshal(objContents, &submissionData)
				if err != nil {
					log.Fatalf("Error unmarshaling bucket content: %v\n", err)
				}

				if submissionData.GraphqlControlPort != 0 {
					if (identity["public-key"] == submissionData.Submitter.String()) && (identity["public-ip"] == submissionData.RemoteAddr) && (identity["graphql-port"] == strconv.Itoa(submissionData.GraphqlControlPort)) {
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
				} else {
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
				}
			}
		}

		uptimePercent := (float64(len(uptime)) / 47.0) * 100
		if uptimePercent > 100.00 {
			uptimePercent = 100.00
		}
		identity["uptime"] = fmt.Sprintf("%.2f%%", (float64(len(uptime))/47.0)*100)
	}
}
