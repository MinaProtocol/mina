package itn_uptime_analyzer

// The column in which the identity of the block producers are written
const IDENTITY_COLUMN = "A"

func GetBucketName(config AppConfig) string {
	return config.Aws.AccountId + "-block-producers-uptime"
}
