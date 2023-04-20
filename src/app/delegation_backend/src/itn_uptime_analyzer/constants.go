package itn_uptime_analyzer

import (
	"os"
)

const ITN_UPTIME_ANALYZER_SHEET = "Sheet1"
const IDENTITY_COLUMN = "A"

const PROD_OUTPUT_SPREADSHEET_ID = ""

const TEST_OUTPUT_SPREADSHEET_ID = "1kFjYo8THbQJkN1Jf_rzdysiMxwM_gHWYzOCBJnCfxjA"
const TEST_CLOUD_BUCKET_NAME = "georgeee-uptime-itn-test-1"

func OutputSpreadsheetId() string {
	if os.Getenv("TEST") == "" {
		return PROD_OUTPUT_SPREADSHEET_ID
	} else {
		return TEST_OUTPUT_SPREADSHEET_ID
	}
}