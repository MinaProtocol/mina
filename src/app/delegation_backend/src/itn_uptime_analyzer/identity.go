package itn_uptime_analyzer

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"io"
	"strconv"
	"strings"
	"time"

	dg "block_producers_uptime/delegation_backend"

	"github.com/aws/aws-sdk-go-v2/service/s3"
	logging "github.com/ipfs/go-log/v2"
	sheets "google.golang.org/api/sheets/v4"
)

// The graphQLPort parameter should be optional but Golang doesn't permit that
// As a workaround we use a pointer that can be defined as nil
type Identity struct {
	id, publicKey, publicIp, uptime string
	graphQLPort                     *string
}

// Custom function to check if identity is in array
func IsIdentityInArray(id string, identities []Identity) bool {
	for _, identity := range identities {
		if identity.id == id {
			return true
		}
	}
	return false
}

// Goes through each submission and adds an identity type to a map
// Identity is constructed based on the payload that the BP sends which may hold pubkey, ip address and graphqlport
func CreateIdentities(config AppConfig, sheet *sheets.Service, ctx dg.AwsContext, log *logging.ZapEventLogger, sheetTitle string, currentTime time.Time, executionInterval int) []Identity {

	currentDate := currentTime.Format("2006-01-02")
	lastExecutionTime := GetLastExecutionTime(config, sheet, log, sheetTitle, currentTime, executionInterval)

	prefixCurrent := strings.Join([]string{ctx.Prefix, "submissions", currentDate}, "/")

	var identities []Identity // Create an empty array of Identity types

	var submissionData dg.MetaToBeSaved

	input := &s3.ListObjectsV2Input{
		Bucket: ctx.BucketName,
		Prefix: &prefixCurrent,
	}

	// Paginate through ListObjects results

	paginator := s3.NewListObjectsV2Paginator(ctx.Client, input)

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx.Context)
		if err != nil {
			log.Fatalf("Getting next page of paginator (BPU bucket): %v\n", err)
		}

		for _, obj := range page.Contents {
			submissionTime, err := time.Parse(time.RFC3339, (*obj.Key)[32:52]) // Between characters 32 and 52 lies the timestamp of a submission
			if err != nil {
				log.Fatalf("Error parsing time: %v\n", err)
			}

			if (submissionTime.After(lastExecutionTime)) && (submissionTime.Before(currentTime)) {

				var identity Identity

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
					identity = GetFullIdentity(submissionData.Submitter.String(), submissionData.RemoteAddr, strconv.Itoa(submissionData.GraphqlControlPort))
				} else {
					identity = GetPartialIdentity(submissionData.Submitter.String(), submissionData.RemoteAddr)
				}

				if !IsIdentityInArray(identity.id, identities) {
					identities = append(identities, identity)
				}
			}
		}
	}
	return identities
}

// Returns an Identity type identified by a hash value as an id
// The identity returned by this is fully unique
func GetFullIdentity(pubKey string, ip string, graphqlPort string) Identity {
	s := strings.Join([]string{pubKey, ip, graphqlPort}, "-")
	id := md5.Sum([]byte(s)) // Create a hash value and use it as id

	identity := Identity{
		id:          hex.EncodeToString(id[:]),
		publicKey:   pubKey,
		publicIp:    ip,
		uptime:      "",
		graphQLPort: &graphqlPort,
	}

	return identity
}

// Returns an Identity type identified by a hash value as an id
// The identity returned by this is partially unique
func GetPartialIdentity(pubKey string, ip string) Identity {
	s := strings.Join([]string{pubKey, ip}, "-")
	id := md5.Sum([]byte(s)) // Create a hash value and use it as id

	identity := Identity{
		id:        hex.EncodeToString(id[:]),
		publicKey: pubKey,
		publicIp:  ip,
		uptime:    "",
	}

	return identity
}
