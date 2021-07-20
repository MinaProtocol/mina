package delegation_backend

import (
  sheets "google.golang.org/api/sheets/v4"
  logging "github.com/ipfs/go-log/v2"
)

func processRows (rows [][](interface{})) Whitelist {
  wl := make(Whitelist)
  for _, row := range rows {
    if len(row) > 0 {
      switch v := row[0].(type) {
        case string:
          var pk Pk
          err := StringToPk(&pk, v)
          if err == nil {
            wl[pk] = true // we need something to be provided as value
          }
      }
    }
  }
  return wl
}

func RetrieveWhitelist (service *sheets.Service, log *logging.ZapEventLogger) Whitelist {
  col := DELEGATION_WHITELIST_COLUMN
  readRange := DELEGATION_WHITELIST_LIST + "!" + col + ":" + col
  spId := DELEGATION_WHITELIST_SPREADSHEET_ID
  resp, err := service.Spreadsheets.Values.Get(spId, readRange).Do()
  if err != nil {
    log.Fatalf("Unable to retrieve data from sheet: %v", err)
  }
  return processRows(resp.Values)
}
