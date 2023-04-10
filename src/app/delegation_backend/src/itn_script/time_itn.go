package itn_script

import (
	logging "github.com/ipfs/go-log/v2"

	"fmt"
	"time"
	"strings"
	"strconv"
	. "delegation_backend"
)

func getCurrentTime() string {
	currentTime := time.Now()
	return currentTime.Format(time.RFC3339)
}

func getLastExecutionTime(currentDateString string) string {
	// Get last execution of application

	hourIndex := strings.Index(currentDateString, strconv.Itoa(currentTime.Hour()))
	currentHour, err := strconv.Atoi(currentDateString[hourIndex:hourIndex+2])

	var lastExecutionHour string

	if err != nil {
			log.Fatalf("Error getting current hour: %v", err)
	}
	if currentHour < 12 {
		lastExecutionHour = strconv.Itoa(24 + (currentHour - 12))
	} else {
		if len(strconv.Itoa(currentHour - 12)) == 1 {
			lastExecutionHour = 	strings.Join([]string{"0", strconv.Itoa(currentHour - 12)}, "")
		} else {
		lastExecutionHour = strconv.Itoa(currentHour - 12)
		}
	}

	lastExecutionTime := strings.Join([]string{currentDateString[:hourIndex], lastExecutionHour, currentDateString[hourIndex+2:]}, "")
	return lastExecutionTime
}