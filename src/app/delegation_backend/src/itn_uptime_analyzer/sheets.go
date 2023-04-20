package itn_uptime_analyzer

import (
	sheets "google.golang.org/api/sheets/v4"
	"strings"
	"fmt"
	logging "github.com/ipfs/go-log/v2"
	// "google.golang.org/api/option"
)

// This function returns true if the identity is present
// and the row index
// If the identity is not present it returns false and searches for the
// closest relative of the identity (same pubkey or same ip)
// If nothing was found it returns false and 0 as the row index

func (identity Identity) GetCell(client *sheets.Service, log *logging.ZapEventLogger) (exactMatch bool, rowIndex int, firstEmptyRow int) {
	exactMatch = false
	rowIndex = 0
	firstEmptyRow = 1
	col := IDENTITY_COLUMN
	readRange := ITN_UPTIME_ANALYZER_SHEET + "!" + col + ":" + col
	spId := OutputSpreadsheetId()
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

	if exactMatch == false {
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

func (identity Identity) AppendNext(client *sheets.Service, log *logging.ZapEventLogger) {
	col := IDENTITY_COLUMN
	readRange := ITN_UPTIME_ANALYZER_SHEET + "!" + col + ":" + col
	spId := OutputSpreadsheetId()

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

func (identity Identity) InsertBelow(client *sheets.Service, log *logging.ZapEventLogger, rowIndex int) {
	col := IDENTITY_COLUMN
	readRange := fmt.Sprintf("%s!%s%d:%s%d", ITN_UPTIME_ANALYZER_SHEET, col, rowIndex + 1, col, rowIndex + 1)
	spId := OutputSpreadsheetId()

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

func (identity Identity) AppendUptime(client *sheets.Service, log *logging.ZapEventLogger, rowIndex int) {
	readRange := fmt.Sprintf("%s!A%d:Z%d", ITN_UPTIME_ANALYZER_SHEET, rowIndex, rowIndex)
	spId := OutputSpreadsheetId()

	resp, err := client.Spreadsheets.Values.Get(spId, readRange).Do()
	if err != nil {
		log.Fatalf("Unable to retrieve data from sheet: %v", err)
	}

	var nextEmptyColumn int = len(resp.Values[0])

	for index, value := range resp.Values[0] {
		if value == "" {
				nextEmptyColumn = index + 1
				break
		}
	}

	updateRange := fmt.Sprintf("%s!%s%d", ITN_UPTIME_ANALYZER_SHEET, string(nextEmptyColumn + 65), rowIndex)

	var cellValue []interface{}

	if (len(identity["uptime"]) >= 47) {
		cellValue = []interface{}{"up"}
	} else {
		cellValue = []interface{}{"not up"}
	}

	valueRange := sheets.ValueRange{
		Values: [][]interface{}{cellValue},
	}

	_, err = client.Spreadsheets.Values.Append(spId, updateRange, &valueRange).ValueInputOption("USER_ENTERED").Do()
	if err != nil {
		log.Fatalf("Unable to insert data in sheet: %v", err)
	}
}