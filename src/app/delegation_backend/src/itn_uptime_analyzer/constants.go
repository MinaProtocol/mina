package itn_uptime_analyzer

const IDENTITY_COLUMN = "A"

func GetBucketName(config AppConfig) string {
	return config.Aws.AccountId + "-block-producers-uptime"
}
