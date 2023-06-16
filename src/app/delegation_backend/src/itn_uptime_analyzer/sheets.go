package itn_uptime_analyzer

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	logging "github.com/ipfs/go-log/v2"
	sheets "google.golang.org/api/sheets/v4"
)

// This function returns true if the identity is present
// and the row index
// If the identity is not present it returns false and searches for the
// closest relative of the identity (same pubkey or same ip)
// If nothing was found it returns false and 0 as the row index

func (identity Identity) GetCell(config AppConfig, client *sheets.Service, log *logging.ZapEventLogger) (exactMatch bool, rowIndex int, firstEmptyRow int) {
	exactMatch = false
	rowIndex = 0
	firstEmptyRow = 1
	col := IDENTITY_COLUMN
	readRange := ITN_UPTIME_ANALYZER_SHEET + "!" + col + ":" + col
	spId := config.AnalyzerOutputGsheetId
	resp, err := client.Spreadsheets.Values.Get(spId, readRange).Do()
	if err != nil {
		log.Fatalf("Unable to retrieve data from sheet: %v", err)
	}

	identityString := strings.Join([]string{identity["public-key"], identity["public-ip"]}, "-")

	for index, row := range resp.Values {
		if row[0] == identityString {
			rowIndex = index + 1
			exactMatch = true
			break
		}
		firstEmptyRow = firstEmptyRow + 1
	}

	if !exactMatch {
		for index, row := range resp.Values {
			str := fmt.Sprintf("%v", row[0])
			if strings.Split(str, "-")[0] == identity["public-key"] {
				rowIndex = index + 1
				exactMatch = false
			}
		}
	}

	return exactMatch, rowIndex, firstEmptyRow
}

// Appends the identity string of the node to the first column

func (identity Identity) AppendNext(config AppConfig, client *sheets.Service, log *logging.ZapEventLogger) {
	col := IDENTITY_COLUMN
	readRange := ITN_UPTIME_ANALYZER_SHEET + "!" + col + ":" + col
	spId := config.AnalyzerOutputGsheetId

	identityString := strings.Join([]string{identity["public-key"], identity["public-ip"]}, "-")

	cellValue := []interface{}{identityString}

	valueRange := sheets.ValueRange{
		Values: [][]interface{}{cellValue},
	}

	_, err := client.Spreadsheets.Values.Append(spId, readRange, &valueRange).ValueInputOption("USER_ENTERED").Do()
	if err != nil {
		log.Fatalf("Unable to append data to sheet: %v", err)
	}
}

// Inserts the identity string of the node in the first column under rowIndex

func (identity Identity) InsertBelow(config AppConfig, client *sheets.Service, log *logging.ZapEventLogger, rowIndex int) {
	col := IDENTITY_COLUMN
	readRange := fmt.Sprintf("%s!%s%d:%s%d", ITN_UPTIME_ANALYZER_SHEET, col, rowIndex+1, col, rowIndex+1)
	spId := config.AnalyzerOutputGsheetId

	identityString := strings.Join([]string{identity["public-key"], identity["public-ip"]}, "-")

	cellValue := []interface{}{identityString}

	valueRange := sheets.ValueRange{
		Values: [][]interface{}{cellValue},
	}

	_, err := client.Spreadsheets.Values.Append(spId, readRange, &valueRange).ValueInputOption("USER_ENTERED").InsertDataOption("INSERT_ROWS").Do()
	if err != nil {
		log.Fatalf("Unable to insert data in sheet: %v", err)
	}
}

// Finds the first empty column on the row specified and puts up or not up

func (identity Identity) AppendUptime(config AppConfig, client *sheets.Service, log *logging.ZapEventLogger, rowIndex int) {
	readRange := fmt.Sprintf("%s!A%d:Z%d", ITN_UPTIME_ANALYZER_SHEET, 1, 1)
	spId := config.AnalyzerOutputGsheetId

	resp, err := client.Spreadsheets.Values.Get(spId, readRange).Do()
	if err != nil {
		log.Fatalf("Unable to retrieve data from sheet: %v\n", err)
	}

	var nextEmptyColumn int = len(resp.Values[0])

	updateRange := fmt.Sprintf("%s!%s%d", ITN_UPTIME_ANALYZER_SHEET, string(nextEmptyColumn+65), rowIndex)

	var cellValue []interface{}

	uptimeArrayLength, err := strconv.Atoi(identity["uptime"])
	if err != nil {
		log.Fatalf("Unable to retrieve data from sheet: %v\n", err)
	}

	if uptimeArrayLength >= 47 {
		cellValue = []interface{}{"up"}
	} else {
		cellValue = []interface{}{"not up"}
	}

	valueRange := sheets.ValueRange{
		Values: [][]interface{}{cellValue},
	}

	_, err = client.Spreadsheets.Values.Append(spId, updateRange, &valueRange).ValueInputOption("USER_ENTERED").Do()
	if err != nil {
		log.Fatalf("Unable to insert data in sheet: %v\n", err)
	}
}

// Tracks the date of execution on the top row of the spreadsheet

func MarkExecution(config AppConfig, client *sheets.Service, log *logging.ZapEventLogger) {
	readRange := fmt.Sprintf("%s!A%d:Z%d", ITN_UPTIME_ANALYZER_SHEET, 1, 1)
	spId := config.AnalyzerOutputGsheetId

	currentTime := GetCurrentTime()
	lastExecutionTime := GetLastExecutionTime(currentTime)

	timeInterval := strings.Join([]string{currentTime.Format(time.RFC3339), lastExecutionTime.Format(time.RFC3339)}, " - ")

	resp, err := client.Spreadsheets.Values.Get(spId, readRange).Do()
	if err != nil {
		log.Fatalf("Unable to retrieve data from sheet: %v", err)
	}

	var nextEmptyColumn int = len(resp.Values[0])

	updateRange := fmt.Sprintf("%s!%s%d", ITN_UPTIME_ANALYZER_SHEET, string(nextEmptyColumn+65), 1)

	cellValue := []interface{}{timeInterval}

	valueRange := sheets.ValueRange{
		Values: [][]interface{}{cellValue},
	}

	_, err = client.Spreadsheets.Values.Append(spId, updateRange, &valueRange).ValueInputOption("USER_ENTERED").Do()
	if err != nil {
		log.Fatalf("Unable to insert data in sheet: %v", err)
	}
}
