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

func (identity Identity) GetCell(client *sheets.Service, log *logging.ZapEventLogger) (exactMatch bool, rowIndex int) {
	exactMatch = false
	rowIndex = 0
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

	return exactMatch, rowIndex 
}

func (identity Identity) AddNext(client *sheets.Service, log *logging.ZapEventLogger){

}

func (identity Identity) InsertBelow(client *sheets.Service, log *logging.ZapEventLogger, rowIndex int){

}