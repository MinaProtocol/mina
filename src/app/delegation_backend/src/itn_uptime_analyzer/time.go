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
func GetLastExecutionTime(config AppConfig, client *sheets.Service, log *logging.ZapEventLogger, sheetTitle string) time.Time {
	readRange := fmt.Sprintf("%s!A%d:Z%d", sheetTitle, 1, 1)
	spId := config.AnalyzerOutputGsheetId

	resp, err := client.Spreadsheets.Values.Get(spId, readRange).Do()
	if err != nil {
		log.Fatalf("Unable to retrieve data from sheet: %v", err)
	}

	var lastFilledColumn int = len(resp.Values[0]) - 1

	readRange = fmt.Sprintf("%s!%s%d", sheetTitle, string(lastFilledColumn+65), 1)

	lastTimeWindow := resp.Values[0][lastFilledColumn]

	stringSplit := strings.SplitAfter(fmt.Sprint(lastTimeWindow), " - ")
	lastExecutionBasedOnSheets := stringSplit[len(stringSplit)-1]

	lastExecutionBasedOnSheetsAsTime, err := time.Parse(time.RFC3339, lastExecutionBasedOnSheets)
	if err != nil {
		log.Fatalf("Unable to parse string to time: %v", err)
	}

	timeDiffHours := time.Since(lastExecutionBasedOnSheetsAsTime).Hours()

	if !strings.HasPrefix(lastExecutionBasedOnSheets, "Node") && (lastExecutionBasedOnSheets != "") && (timeDiffHours > time.Since(GetCurrentTime().Add(-11*time.Hour)).Hours()) {
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

func IdentifyWeek(config AppConfig, client *sheets.Service, log *logging.ZapEventLogger) (string, error) {
	outputSheets, err := GetSheets(config, client, log)

	if err != nil {
		log.Fatalf("Error getting sheet names: %v", err)
	}

	lastSheet := outputSheets[len(outputSheets)-1]

	readRange := fmt.Sprintf("%s!A%d:Z%d", lastSheet.Properties.Title, 1, 1)
	spId := config.AnalyzerOutputGsheetId

	resp, err := client.Spreadsheets.Values.Get(spId, readRange).Do()
	if err != nil {
		log.Fatalf("Unable to retrieve data from sheet: %v", err)
	}

	var lastFilledColumn int = len(resp.Values[0]) - 1

	currentDate := GetCurrentTime().Format("2006-01-02")
	oneWeekLater := GetCurrentTime().Add(7 * 24 * time.Hour).Format("2006-01-02")
	sheetTitle := strings.Join([]string{currentDate, oneWeekLater}, " - ")

	if lastFilledColumn >= 14 {
		err := CreateSheet(config, client, log, sheetTitle)
		if err != nil {
			log.Fatalf("Unable to create new sheet for spreadsheet: %v", err)
		}

		return sheetTitle, nil
	} else {
		return lastSheet.Properties.Title, nil
	}
}
