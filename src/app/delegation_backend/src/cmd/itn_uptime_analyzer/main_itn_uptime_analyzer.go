package main

import (
	logging "github.com/ipfs/go-log/v2"
	"cloud.google.com/go/storage"
	sheets "google.golang.org/api/sheets/v4"
	"context"
	itn "block_producers_uptime/itn_uptime_analyzer"
	dg "block_producers_uptime/delegation_backend"
)

func main (){

	// Setting up logging for application

	logging.SetupLogging(logging.Config{
		Format: logging.JSONOutput,
		Stderr: true,
		Stdout: false,
		Level:  logging.LevelDebug,
		File:   "",
	})
	log := logging.Logger("itn availability script")
	log.Infof("itn availability script has the following logging subsystems active: %v", logging.GetSubsystems())

	// Empty context object and initializing memory for application

	ctx := context.Background()
	app := new(dg.App)
	app.Log = log

	// Create Google Cloud client

	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Fatalf("Error creating Cloud client: %v", err)
		return
	}

	sheetsService, err := sheets.NewService(ctx)
	if err != nil {
		log.Fatalf("Error creating Sheets service: %v", err)
		return
	}

	identities := itn.CreateIdentities(ctx, client, log)

	// Go over identities and calculate uptime

	for _, identity := range identities {

		identity.GetUptime(ctx, client, log)

		exactMatch, rowIndex, firstEmptyRow := identity.GetCell(sheetsService, log)

		if exactMatch {
			identity.AppendUptime(sheetsService, log, rowIndex)
		} else if (!exactMatch) && (rowIndex == 0) {
			identity.AppendNext(sheetsService, log)
			identity.AppendUptime(sheetsService, log, firstEmptyRow)
		} else if (!exactMatch) && (rowIndex != 0) {
			identity.InsertBelow(sheetsService, log, rowIndex)
			identity.AppendUptime(sheetsService, log, rowIndex+1)
		}
	}

	itn.MarkExecution(sheetsService, log)

}