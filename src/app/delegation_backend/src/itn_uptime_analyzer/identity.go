package itn_uptime_analyzer

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"strings"
	"time"
	"cloud.google.com/go/storage"
	dg "block_producers_uptime/delegation_backend"
	logging "github.com/ipfs/go-log/v2"
	"context"
	"google.golang.org/api/iterator"
)

type Identity map[string]string

func CreateIdentities(ctx context.Context, client *storage.Client, log *logging.ZapEventLogger) map[string]Identity {

	// currentTime := itn.GetCurrentTime()
	currentTime := time.Date(2023, time.April, 1, 23, 59, 59, 0, time.UTC)
	currentDateString := currentTime.Format(time.RFC3339)[:10]
	lastExecutionTime := GetLastExecutionTime(currentTime)

	prefixCurrent := strings.Join([]string{"submissions", currentDateString}, "/")
	submissions := client.Bucket(dg.CloudBucketName()).Objects(ctx, &storage.Query{Prefix: prefixCurrent})

	identities := make(map[string]Identity) // Create a map for unique identities
	
	var submissionData dg.MetaToBeSaved

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
				log.Fatalf("Error parsing time: %v\n", err)
			}
	
			// Check if the submission is in the previous twelve hour window
	
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
		
				identity := GetIdentity(submissionData.Submitter.String(), "45.45.45.46") // change the IP back to submissionData["remote_addr"]
				if _, inMap := identities[identity["id"]]; !inMap {
					AddIdentity(identity, identities)
				}
	
				reader.Close()
	
			}
		}
	return identities
}

func GetIdentity(pubKey string, ip string) map[string]string {
	s := strings.Join([]string{pubKey, ip}, "-")
	id := md5.Sum([]byte(s)) // Create a hash value and use it as id

	identity := map[string]string{
		"id": hex.EncodeToString(id[:]),
		"public-key": pubKey,
		"public-ip": ip,
	}

	return identity
}

func AddIdentity(identity Identity, identities map[string]Identity) {
	identities[identity["id"]] = identity
}