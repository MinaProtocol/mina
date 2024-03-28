package delegation_backend

import (
	"encoding/json"
	"os"

	logging "github.com/ipfs/go-log/v2"
)

func loadAwsCredentials(filename string, log logging.EventLogger) {
	file, err := os.Open(filename)
	if err != nil {
		log.Fatalf("Error loading credentials file: %s", err)
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	var credentials AwsCredentials
	err = decoder.Decode(&credentials)
	if err != nil {
		log.Fatalf("Error loading credentials file: %s", err)
	}
	os.Setenv("AWS_ACCESS_KEY_ID", credentials.AccessKeyId)
	os.Setenv("AWS_SECRET_ACCESS_KEY", credentials.SecretAccessKey)
}

func LoadEnv(log logging.EventLogger) AppConfig {
	var config AppConfig

	configFile := os.Getenv("CONFIG_FILE")
	if configFile != "" {
		file, err := os.Open(configFile)
		if err != nil {
			log.Fatalf("Error loading config file: %s", err)
		}
		defer file.Close()
		decoder := json.NewDecoder(file)
		err = decoder.Decode(&config)
		if err != nil {
			log.Fatalf("Error loading config file: %s", err)
		}
	} else {
		networkName := os.Getenv("CONFIG_NETWORK_NAME")
		if networkName == "" {
			log.Fatal("missing NETWORK_NAME environment variable")
		}

		gsheetId := os.Getenv("CONFIG_GSHEET_ID")
		if gsheetId == "" {
			log.Fatal("missing GSHEET_ID environment variable")
		}

		awsRegion := os.Getenv("CONFIG_AWS_REGION")
		if awsRegion == "" {
			log.Fatal("missing AWS_REGION environment variable")
		}

		awsAccountId := os.Getenv("CONFIG_AWS_ACCOUNT_ID")
		if awsAccountId == "" {
			log.Fatal("missing AWS_ACCOUNT_ID environment variable")
		}

		config = AppConfig{
			NetworkName: networkName,
			GsheetId:    gsheetId,
			Aws: AwsConfig{
				Region:    awsRegion,
				AccountId: awsAccountId,
			},
		}
	}

	awsCredentialsFile := os.Getenv("AWS_CREDENTIALS_FILE")
	if awsCredentialsFile != "" {
		loadAwsCredentials(awsCredentialsFile, log)
	}

	return config
}

type AwsConfig struct {
	Region    string `json:"region"`
	AccountId string `json:"account_id"`
}

type AppConfig struct {
	Aws         AwsConfig `json:"aws"`
	NetworkName string    `json:"network_name"`
	GsheetId    string    `json:"gsheet_id"`
}

type AwsCredentials struct {
	AccessKeyId     string `json:"access_key_id"`
	SecretAccessKey string `json:"secret_access_key"`
}
