package itn_uptime_analyzer

const ITN_UPTIME_ANALYZER_SHEET = "Sheet1"
const IDENTITY_COLUMN = "A"

func GetBucketName(config AppConfig) string {
	return config.Aws.AccountId + "-block-producers-uptime"
}
