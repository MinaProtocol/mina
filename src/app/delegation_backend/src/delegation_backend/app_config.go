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
		if config.InMemory == (config.Aws != nil) {
			log.Fatal("Exactly one of 'aws' and 'in_memory' should be set in config")
		}
		if (len(config.Whitelist) == 0) == (config.GsheetId == "") {
			log.Fatal("Exactly one of 'whitelist' and 'gsheet_id' should be set in config")
		}
	} else {
		gsheetId := os.Getenv("CONFIG_GSHEET_ID")
		if gsheetId == "" {
			log.Fatal("missing CONFIG_GSHEET_ID environment variable")
		}

		awsPrefix := os.Getenv("CONFIG_AWS_PREFIX")
		if awsPrefix == "" {
			log.Fatal("missing CONFIG_AWS_PREFIX environment variable")
		}

		awsRegion := os.Getenv("CONFIG_AWS_REGION")
		if awsRegion == "" {
			log.Fatal("missing CONFIG_AWS_REGION environment variable")
		}

		awsAccountId := os.Getenv("CONFIG_AWS_ACCOUNT_ID")
		if awsAccountId == "" {
			log.Fatal("missing CONFIG_AWS_ACCOUNT_ID environment variable")
		}

		config = AppConfig{
			GsheetId: gsheetId,
			Aws: &AwsConfig{
				Prefix:    awsPrefix,
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
	Prefix    string `json:"prefix"`
}

type AppConfig struct {
	Aws       *AwsConfig `json:"aws"`
	GsheetId  string     `json:"gsheet_id"`
	Whitelist []string   `json:"whitelist"`
	InMemory  bool       `json:"in_memory"`
}

type AwsCredentials struct {
	AccessKeyId     string `json:"access_key_id"`
	SecretAccessKey string `json:"secret_access_key"`
}

func (config *AwsConfig) GetBucketName() string {
	return config.AccountId + "-block-producers-uptime"
}
