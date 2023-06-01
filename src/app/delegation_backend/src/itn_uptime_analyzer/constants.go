package itn_uptime_analyzer

import (
	"os"
)

const ITN_UPTIME_ANALYZER_SHEET = "Sheet1"
const IDENTITY_COLUMN = "A"

const PROD_OUTPUT_SPREADSHEET_ID = "16i0zD5emJyByx9uRFJi2rKJrgh_Zevf8oe0EBefwkPs"

const TEST_OUTPUT_SPREADSHEET_ID = "1kFjYo8THbQJkN1Jf_rzdysiMxwM_gHWYzOCBJnCfxjA"

const ITN_OUTPUT_SPREADSHEET_ID = "16i0zD5emJyByx9uRFJi2rKJrgh_Zevf8oe0EBefwkPs"

func OutputSpreadsheetId() string {
	if os.Getenv("TEST") == "" {
		if os.Getenv("NETWORK") == "itn" {
			return ITN_OUTPUT_SPREADSHEET_ID
		}
		return PROD_OUTPUT_SPREADSHEET_ID
	} else {
		return TEST_OUTPUT_SPREADSHEET_ID
	}
}
