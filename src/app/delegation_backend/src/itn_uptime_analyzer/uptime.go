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

func (identity Identity) GetUptimeOfToday(config AppConfig, sheet *sheets.Service, ctx dg.AwsContext, log *logging.ZapEventLogger, sheetTitle string, currentTime time.Time, syncPeriod int, executionInterval int) {
	fmt.Println("Running uptime today")
	currentDate := currentTime.Format("2006-01-02")
	lastExecutionTime := GetLastExecutionTime(config, sheet, log, sheetTitle, currentTime, executionInterval)

	fmt.Printf("Current time: %v\n", currentTime)
	fmt.Printf("Last execution time: %v\n", lastExecutionTime)

	numberOfSubmissionsNeeded := (60 / syncPeriod) * executionInterval

	fmt.Printf("Number of submissions needed: %v\n", numberOfSubmissionsNeeded)

	prefixToday := strings.Join([]string{ctx.Prefix, "submissions", currentDate}, "/")

	inputToday := &s3.ListObjectsV2Input{
		Bucket: ctx.BucketName,
		Prefix: &prefixToday,
	}

	paginatorToday := s3.NewListObjectsV2Paginator(ctx.Client, inputToday)

	var submissionDataToday dg.MetaToBeSaved
	var lastSubmissionTimeString string
	var lastSubmissionTime time.Time
	var uptimeToday []bool

	for paginatorToday.HasMorePages() {
		page, err := paginatorToday.NextPage(ctx.Context)
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

				err = json.Unmarshal(objContents, &submissionDataToday)
				if err != nil {
					log.Fatalf("Error unmarshaling bucket content: %v\n", err)
				}

				if submissionDataToday.GraphqlControlPort != 0 {
					if (identity["public-key"] == submissionDataToday.Submitter.String()) && (identity["public-ip"] == submissionDataToday.RemoteAddr) && (identity["graphql-port"] == strconv.Itoa(submissionDataToday.GraphqlControlPort)) {
						if lastSubmissionTimeString != "" {
							lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionTimeString)
							if err != nil {
								log.Fatalf("Error parsing time: %v\n", err)
							}
						}

						currentSubmissionTime, err := time.Parse(time.RFC3339, submissionDataToday.CreatedAt)
						if err != nil {
							log.Fatalf("Error parsing time: %v", err)
						}

						if (lastSubmissionTimeString != "") && (currentSubmissionTime.After(lastSubmissionTime.Add(time.Duration(syncPeriod-5) * time.Minute))) && (currentSubmissionTime.Before(lastSubmissionTime.Add(time.Duration(syncPeriod+5) * time.Minute))) {
							uptimeToday = append(uptimeToday, true)
							lastSubmissionTimeString = submissionDataToday.CreatedAt
						} else if lastSubmissionTimeString == "" {
							uptimeToday = append(uptimeToday, true)
							lastSubmissionTimeString = submissionDataToday.CreatedAt
						}

					}
				} else {
					if (identity["public-key"] == submissionDataToday.Submitter.String()) && (identity["public-ip"] == submissionDataToday.RemoteAddr) {
						if lastSubmissionTimeString != "" {
							lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionTimeString)
							if err != nil {
								log.Fatalf("Error parsing time: %v\n", err)
							}
						}

						currentSubmissionTime, err := time.Parse(time.RFC3339, submissionDataToday.CreatedAt)
						if err != nil {
							log.Fatalf("Error parsing time: %v", err)
						}

						if (lastSubmissionTimeString != "") && (currentSubmissionTime.After(lastSubmissionTime.Add(time.Duration(syncPeriod-5) * time.Minute))) && (currentSubmissionTime.Before(lastSubmissionTime.Add(time.Duration(syncPeriod+5) * time.Minute))) {
							uptimeToday = append(uptimeToday, true)
							lastSubmissionTimeString = submissionDataToday.CreatedAt
						} else if lastSubmissionTimeString == "" {
							uptimeToday = append(uptimeToday, true)
							lastSubmissionTimeString = submissionDataToday.CreatedAt
						}

					}
				}
			}
		}

		fmt.Printf("Uptime today: %v\n", len(uptimeToday))

		uptimePercent := (float64(len(uptimeToday)) / float64(numberOfSubmissionsNeeded)) * 100
		if uptimePercent > 100.00 {
			uptimePercent = 100.00
		}
		identity["uptime"] = fmt.Sprintf("%.2f%%", uptimePercent)
	}
}

// This function does the same as the one above only that it calculates the difference between the time elapsed
// today and 12 hours and enters the folder for the previous day aswell
func (identity Identity) GetUptimeOfTwoDays(config AppConfig, sheet *sheets.Service, ctx dg.AwsContext, log *logging.ZapEventLogger, sheetTitle string, currentTime time.Time, syncPeriod int, executionInterval int) {
	fmt.Println("Running uptime two days")
	currentDate := currentTime.Format("2006-01-02")
	lastExecutionTime := GetLastExecutionTime(config, sheet, log, sheetTitle, currentTime, executionInterval)

	fmt.Printf("Current time: %v\n", currentTime)
	fmt.Printf("Last execution time: %v\n", lastExecutionTime)

	yesterdaysDate := lastExecutionTime.Format("2006-01-02")

	numberOfSubmissionsNeeded := (60 / syncPeriod) * executionInterval

	fmt.Printf("Number of submissions needed: %v\n", numberOfSubmissionsNeeded)

	prefixToday := strings.Join([]string{ctx.Prefix, "submissions", currentDate}, "/")
	prefixYesterday := strings.Join([]string{ctx.Prefix, "submissions", yesterdaysDate}, "/")

	inputToday := &s3.ListObjectsV2Input{
		Bucket: ctx.BucketName,
		Prefix: &prefixToday,
	}

	inputYesterday := &s3.ListObjectsV2Input{
		Bucket: ctx.BucketName,
		Prefix: &prefixYesterday,
	}

	paginatorToday := s3.NewListObjectsV2Paginator(ctx.Client, inputToday)
	paginatorYesterday := s3.NewListObjectsV2Paginator(ctx.Client, inputYesterday)

	var submissionDataToday dg.MetaToBeSaved
	var submissionDataYesterday dg.MetaToBeSaved
	var lastSubmissionTimeString string
	var lastSubmissionTime time.Time
	var uptimeToday []bool
	var uptimeYesterday []bool

	for paginatorYesterday.HasMorePages() {
		page, err := paginatorYesterday.NextPage(ctx.Context)
		if err != nil {
			log.Fatalf("Getting next page of paginatorYesterday (BPU bucket): %v\n", err)
		}

		for _, obj := range page.Contents {

			// Convert time of submission to time object for filtering

			submissionTime, err := time.Parse(time.RFC3339, (*obj.Key)[32:52])
			if err != nil {
				log.Fatalf("Error parsing time: %v\n", err)
			}

			if submissionTime.After(lastExecutionTime) && submissionTime.Before(currentTime) {

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

				err = json.Unmarshal(objContents, &submissionDataYesterday)
				if err != nil {
					log.Fatalf("Error unmarshaling bucket content: %v\n", err)
				}

				if submissionDataYesterday.GraphqlControlPort != 0 {
					if (identity["public-key"] == submissionDataYesterday.Submitter.String()) && (identity["public-ip"] == submissionDataYesterday.RemoteAddr) && (identity["graphql-port"] == strconv.Itoa(submissionDataYesterday.GraphqlControlPort)) {
						if lastSubmissionTimeString != "" {
							lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionTimeString)
							if err != nil {
								log.Fatalf("Error parsing time: %v\n", err)
							}
						}

						currentSubmissionTime, err := time.Parse(time.RFC3339, submissionDataYesterday.CreatedAt)
						if err != nil {
							log.Fatalf("Error parsing time: %v", err)
						}

						if (lastSubmissionTimeString != "") && (currentSubmissionTime.After(lastSubmissionTime.Add(time.Duration(syncPeriod-5) * time.Minute))) && (currentSubmissionTime.Before(lastSubmissionTime.Add(time.Duration(syncPeriod+5) * time.Minute))) {
							uptimeYesterday = append(uptimeYesterday, true)
							lastSubmissionTimeString = submissionDataYesterday.CreatedAt
						} else if lastSubmissionTimeString == "" {
							uptimeYesterday = append(uptimeYesterday, true)
							lastSubmissionTimeString = submissionDataYesterday.CreatedAt
						}
					}
				} else {
					if (identity["public-key"] == submissionDataYesterday.Submitter.String()) && (identity["public-ip"] == submissionDataYesterday.RemoteAddr) {
						if lastSubmissionTimeString != "" {
							lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionTimeString)
							if err != nil {
								log.Fatalf("Error parsing time: %v\n", err)
							}
						}

						currentSubmissionTime, err := time.Parse(time.RFC3339, submissionDataYesterday.CreatedAt)
						if err != nil {
							log.Fatalf("Error parsing time: %v", err)
						}

						if (lastSubmissionTimeString != "") && (currentSubmissionTime.After(lastSubmissionTime.Add(time.Duration(syncPeriod-5) * time.Minute))) && (currentSubmissionTime.Before(lastSubmissionTime.Add(time.Duration(syncPeriod+5) * time.Minute))) {
							uptimeYesterday = append(uptimeYesterday, true)
							lastSubmissionTimeString = submissionDataYesterday.CreatedAt
						} else if lastSubmissionTimeString == "" {
							uptimeYesterday = append(uptimeYesterday, true)
							lastSubmissionTimeString = submissionDataYesterday.CreatedAt
						}
					}
				}
			}
		}

		for paginatorToday.HasMorePages() {
			page, err := paginatorToday.NextPage(ctx.Context)
			if err != nil {
				log.Fatalf("Getting next page of paginatorToday (BPU bucket): %v\n", err)
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

					err = json.Unmarshal(objContents, &submissionDataToday)
					if err != nil {
						log.Fatalf("Error unmarshaling bucket content: %v\n", err)
					}

					if submissionDataToday.GraphqlControlPort != 0 {
						if (identity["public-key"] == submissionDataToday.Submitter.String()) && (identity["public-ip"] == submissionDataToday.RemoteAddr) && (identity["graphql-port"] == strconv.Itoa(submissionDataToday.GraphqlControlPort)) {
							if lastSubmissionTimeString != "" {
								lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionTimeString)
								if err != nil {
									log.Fatalf("Error parsing time: %v\n", err)
								}
							}

							currentSubmissionTime, err := time.Parse(time.RFC3339, submissionDataToday.CreatedAt)
							if err != nil {
								log.Fatalf("Error parsing time: %v\n", err)
							}

							if (lastSubmissionTimeString != "") && (currentSubmissionTime.After(lastSubmissionTime.Add(time.Duration(syncPeriod-5) * time.Minute))) && (currentSubmissionTime.Before(lastSubmissionTime.Add(time.Duration(syncPeriod+5) * time.Minute))) {
								uptimeToday = append(uptimeToday, true)
								lastSubmissionTimeString = submissionDataToday.CreatedAt
							} else if lastSubmissionTimeString == "" {
								uptimeToday = append(uptimeToday, true)
								lastSubmissionTimeString = submissionDataToday.CreatedAt
							}

						}
					} else {
						if (identity["public-key"] == submissionDataToday.Submitter.String()) && (identity["public-ip"] == submissionDataToday.RemoteAddr) {
							if lastSubmissionTimeString != "" {
								lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionTimeString)
								if err != nil {
									log.Fatalf("Error parsing time: %v\n", err)
								}
							}

							currentSubmissionTime, err := time.Parse(time.RFC3339, submissionDataToday.CreatedAt)
							if err != nil {
								log.Fatalf("Error parsing time: %v\n", err)
							}

							if (lastSubmissionTimeString != "") && (currentSubmissionTime.After(lastSubmissionTime.Add(time.Duration(syncPeriod-5) * time.Minute))) && (currentSubmissionTime.Before(lastSubmissionTime.Add(time.Duration(syncPeriod+5) * time.Minute))) {
								uptimeToday = append(uptimeToday, true)
								lastSubmissionTimeString = submissionDataToday.CreatedAt
							} else if lastSubmissionTimeString == "" {
								uptimeToday = append(uptimeToday, true)
								lastSubmissionTimeString = submissionDataToday.CreatedAt
							}

						}
					}
				}
			}

			fmt.Printf("Uptime today: %v\n", len(uptimeToday))
			fmt.Printf("Uptime yesterday: %v\n", len(uptimeYesterday))

			uptimePercent := (float64(len(uptimeToday)+len(uptimeYesterday)) / float64(numberOfSubmissionsNeeded)) * 100
			if uptimePercent > 100.00 {
				uptimePercent = 100.00
			}
			identity["uptime"] = fmt.Sprintf("%.2f%%", uptimePercent)
		}
	}
}
