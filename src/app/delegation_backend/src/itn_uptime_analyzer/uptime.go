package itn_uptime_analyzer

import (
	dg "block_producers_uptime/delegation_backend"
	"encoding/json"
	"io"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/s3"
	logging "github.com/ipfs/go-log/v2"
	sheets "google.golang.org/api/sheets/v4"
)

// This function calculates the difference between the time elapsed today and the execution interval, decides if it need to check multiple buckets or not and calculates the uptime
func (identity Identity) GetUptime(config AppConfig, sheet *sheets.Service, ctx dg.AwsContext, log *logging.ZapEventLogger, sheetTitle string, currentTime time.Time, syncPeriod int, executionInterval int) {
	currentDate := currentTime.Format("2006-01-02")
	lastExecutionTime := GetLastExecutionTime(config, sheet, log, sheetTitle, currentTime, executionInterval)

	numberOfSubmissionsNeeded := (60 / syncPeriod) * executionInterval

	prefixToday := strings.Join([]string{ctx.Prefix, "submissions", currentDate}, "/")

	inputToday := &s3.ListObjectsV2Input{
		Bucket: ctx.BucketName,
		Prefix: &prefixToday,
	}

	//Create a regex pattern for finding submissions matching identity pubkey
	regex, err := regexp.Compile(strings.Join([]string{".*-", identity.publicKey, ".json"}, ""))
	if err != nil {
		log.Fatalf("Error creating regular expression out of key: %v\n", err)
	}

	paginatorToday := s3.NewListObjectsV2Paginator(ctx.Client, inputToday)

	var submissionDataToday dg.MetaToBeSaved
	var lastSubmissionTimeString string
	var lastSubmissionTime time.Time
	var uptimeToday []bool
	var uptimeYesterday []bool

	for paginatorToday.HasMorePages() {
		page, err := paginatorToday.NextPage(ctx.Context)
		if err != nil {
			log.Fatalf("Getting next page of paginatorToday (BPU bucket): %v\n", err)
		}

		for _, obj := range page.Contents {

			submissionTime, err := time.Parse(time.RFC3339, (*obj.Key)[32:52])
			if err != nil {
				log.Fatalf("Error parsing time: %v\n", err)
			}

			//Open json file only if the pubkey matches the pubkey in the name
			if regex.MatchString(*obj.Key) {
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
						if (identity.publicKey == submissionDataToday.Submitter.String()) && (identity.publicIp == submissionDataToday.RemoteAddr) && (*identity.graphQLPort == strconv.Itoa(submissionDataToday.GraphqlControlPort)) {
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
								uptimeYesterday = append(uptimeYesterday, true)
								lastSubmissionTimeString = submissionDataToday.CreatedAt
							} else if lastSubmissionTimeString == "" {
								uptimeYesterday = append(uptimeYesterday, true)
								lastSubmissionTimeString = submissionDataToday.CreatedAt
							}
						}
					} else {
						if (identity.publicKey == submissionDataToday.Submitter.String()) && (identity.publicIp == submissionDataToday.RemoteAddr) {
							if lastSubmissionTimeString != "" {
								lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionTimeString)
								if err != nil {
									log.Fatalf("Error parsing time: %v\n", err)
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
			}
		}
	}
	// If the current time is more than the execution interval than it means that submissions from pervious buckets have to be checked
	if SubmissionsInMultipleBuckets(currentTime, executionInterval) {

		yesterdaysDate := lastExecutionTime.Format("2006-01-02")

		prefixYesterday := strings.Join([]string{ctx.Prefix, "submissions", yesterdaysDate}, "/")

		inputYesterday := &s3.ListObjectsV2Input{
			Bucket: ctx.BucketName,
			Prefix: &prefixYesterday,
		}

		paginatorYesterday := s3.NewListObjectsV2Paginator(ctx.Client, inputYesterday)

		var submissionDataYesterday dg.MetaToBeSaved

		for paginatorYesterday.HasMorePages() {
			page, err := paginatorYesterday.NextPage(ctx.Context)
			if err != nil {
				log.Fatalf("Getting next page of paginatorYesterday (BPU bucket): %v\n", err)
			}

			for _, obj := range page.Contents {

				submissionTime, err := time.Parse(time.RFC3339, (*obj.Key)[32:52])
				if err != nil {
					log.Fatalf("Error parsing time: %v\n", err)
				}

				if regex.MatchString(*obj.Key) {
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
							if (identity.publicKey == submissionDataYesterday.Submitter.String()) && (identity.publicIp == submissionDataYesterday.RemoteAddr) && (*identity.graphQLPort == strconv.Itoa(submissionDataYesterday.GraphqlControlPort)) {
								if lastSubmissionTimeString != "" {
									lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionTimeString)
									if err != nil {
										log.Fatalf("Error parsing time: %v\n", err)
									}
								}

								currentSubmissionTime, err := time.Parse(time.RFC3339, submissionDataYesterday.CreatedAt)
								if err != nil {
									log.Fatalf("Error parsing time: %v\n", err)
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
							if (identity.publicKey == submissionDataYesterday.Submitter.String()) && (identity.publicIp == submissionDataYesterday.RemoteAddr) {
								if lastSubmissionTimeString != "" {
									lastSubmissionTime, err = time.Parse(time.RFC3339, lastSubmissionTimeString)
									if err != nil {
										log.Fatalf("Error parsing time: %v\n", err)
									}

									currentSubmissionTime, err := time.Parse(time.RFC3339, submissionDataToday.CreatedAt)
									if err != nil {
										log.Fatalf("Error parsing time: %v\n", err)
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
				}
			}
		}
	}

	uptimePercent := (float64(len(uptimeToday)+len(uptimeYesterday)) / float64(numberOfSubmissionsNeeded)) * 100
	if uptimePercent > 100.00 {
		uptimePercent = 100.00
	}
	identity.uptime = strconv.FormatFloat(uptimePercent, 'f', 2, 64)
}
