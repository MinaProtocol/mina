package itn_uptime_analyzer

// The column in which the identity of the block producers are written
const IDENTITY_COLUMN = "A"
const LETTER_A_ASCII_CODE = 65

func GetBucketName(config AppConfig) string {
	return config.Aws.AccountId + "-block-producers-uptime"
}
