package itn_uptime_analyzer

import (
	"fmt"
	"strings"
	"time"

	logging "github.com/ipfs/go-log/v2"
	sheets "google.golang.org/api/sheets/v4"
)

func GetCurrentTime() time.Time {
	currentTime := time.Now()
	return currentTime
}

// Get last execution time of application
func GetLastExecutionTime(config AppConfig, client *sheets.Service, log *logging.ZapEventLogger) time.Time {
	readRange := fmt.Sprintf("%s!A%d:Z%d", ITN_UPTIME_ANALYZER_SHEET, 1, 1)
	spId := config.AnalyzerOutputGsheetId

	resp, err := client.Spreadsheets.Values.Get(spId, readRange).Do()
	if err != nil {
		log.Fatalf("Unable to retrieve data from sheet: %v", err)
	}

	var lastFilledColumn int = len(resp.Values[0]) - 1

	readRange = fmt.Sprintf("%s!%s%d", ITN_UPTIME_ANALYZER_SHEET, string(lastFilledColumn+65), 1)

	lastTimeWindow := resp.Values[0][lastFilledColumn]

	stringSplit := strings.SplitAfter(fmt.Sprint(lastTimeWindow), " - ")
	lastExecutionBasedOnSheets := stringSplit[len(stringSplit)-1]

	if lastExecutionBasedOnSheets != "" {
		pastTime, err := time.Parse(time.RFC3339, lastExecutionBasedOnSheets)
		if err != nil {
			log.Fatalf("Unable to parse string to time: %v", err)
		}
		return pastTime
	} else {
		currentTime := GetCurrentTime()
		pastTime := currentTime.Add(-12 * time.Hour)
		return pastTime
	}
}
