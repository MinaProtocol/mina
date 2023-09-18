package itn_uptime_analyzer

import (
	"fmt"
	"strings"
	"time"

	logging "github.com/ipfs/go-log/v2"
	sheets "google.golang.org/api/sheets/v4"
)

// Returns current time in UTC format
func GetCurrentTime() time.Time {
	currentTime := time.Now().UTC()
	return currentTime
}

// Checks the spreadsheet for a possible value for the last execution date
// If there is no date, or the date is between the +/- one hour range of the chosen execution interval then the function returns current time minus the execution interval
func GetLastExecutionTime(config AppConfig, client *sheets.Service, log *logging.ZapEventLogger, sheetTitle string, currentTime time.Time, executionInterval int) time.Time {
	readRange := fmt.Sprintf("%s!A%d:Z%d", sheetTitle, 1, 1)
	spId := config.AnalyzerOutputGsheetId

	resp, err := client.Spreadsheets.Values.Get(spId, readRange).Do()
	if err != nil {
		log.Fatalf("Unable to retrieve data from sheet: %v\n", err)
	}

	var lastFilledColumn int = len(resp.Values[0]) - 1
	var lastExecutionBasedOnSheetsAsTime time.Time

	readRange = fmt.Sprintf("%s!%s%d", sheetTitle, string(lastFilledColumn+65), 1)

	lastTimeWindow := resp.Values[0][lastFilledColumn]

	stringSplit := strings.SplitAfter(fmt.Sprint(lastTimeWindow), " - ")
	lastExecutionBasedOnSheets := stringSplit[len(stringSplit)-1]

	if !strings.HasPrefix(lastExecutionBasedOnSheets, "Node") {
		lastExecutionBasedOnSheetsAsTime, err = time.Parse(time.RFC3339, lastExecutionBasedOnSheets)
		if err != nil {
			log.Fatalf("Unable to parse string to time: %v\n", err)
		}
	} else {
		pastTime := currentTime.Add(-time.Duration(executionInterval) * time.Hour)
		return pastTime
	}

	timeDiffHours := time.Since(lastExecutionBasedOnSheetsAsTime).Hours()

	if (lastExecutionBasedOnSheets != "") && (timeDiffHours > time.Since(currentTime.Add(-time.Duration(executionInterval-1)*time.Hour)).Hours()) && (timeDiffHours <= time.Since(currentTime.Add(-time.Duration(executionInterval+1)*time.Hour)).Hours()) {
		pastTime, err := time.Parse(time.RFC3339, lastExecutionBasedOnSheets)
		if err != nil {
			log.Fatalf("Unable to parse string to time: %v\n", err)
		}
		return pastTime
	} else {
		pastTime := currentTime.Add(-time.Duration(executionInterval) * time.Hour)
		return pastTime
	}
}

// Identifies which sheet should the application write to
// Currently one sheet should represent one week
func IdentifyWeek(config AppConfig, client *sheets.Service, log *logging.ZapEventLogger, currentTime time.Time) (string, error) {
	outputSheets, err := GetSheets(config, client, log)

	if err != nil {
		log.Fatalf("Error getting sheet names: %v\n", err)
	}

	lastSheet := outputSheets[len(outputSheets)-1]
	lastSheetSplit := strings.SplitAfter(lastSheet.Properties.Title, " - ")
	lastSheetEndTime, err := time.Parse(lastSheetSplit[len(lastSheetSplit)-1], time.RFC3339)
	if err != nil {
		log.Fatalf("Error parsing time: %v\n", err)
	}

	readRange := fmt.Sprintf("%s!A%d:Z%d", lastSheet.Properties.Title, 1, 1)
	spId := config.AnalyzerOutputGsheetId

	resp, err := client.Spreadsheets.Values.Get(spId, readRange).Do()
	if err != nil {
		log.Fatalf("Unable to retrieve data from sheet: %v\n", err)
	}

	var lastFilledColumn int = len(resp.Values[0]) - 1

	currentDate := currentTime.Format("2006-01-02")
	oneWeekLater := currentTime.Add(7 * 24 * time.Hour).Format("2006-01-02")
	sheetTitle := strings.Join([]string{currentDate, oneWeekLater}, " - ")

	if lastSheetEndTime.Before(currentTime) {
		err := CreateSheet(config, client, log, sheetTitle)
		if err != nil {
			log.Fatalf("Unable to create new sheet for spreadsheet: %v\n", err)
		}

		return sheetTitle, nil
	} else if lastFilledColumn >= 14 {
		err := CreateSheet(config, client, log, sheetTitle)
		if err != nil {
			log.Fatalf("Unable to create new sheet for spreadsheet: %v\n", err)
		}

		return sheetTitle, nil
	} else {
		return lastSheet.Properties.Title, nil
	}
}

// Decides if the application should check one or multiple buckets
func SubmissionsInMultipleBuckets(currentTime time.Time, executionInterval int) bool {
	if currentTime.Hour() < executionInterval {
		return true
	} else if currentTime.Hour() >= executionInterval {
		return false
	}

	return false
}
