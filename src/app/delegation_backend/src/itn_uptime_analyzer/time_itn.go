package itn_script

import (
	"time"
)

func GetCurrentTime() time.Time {
	currentTime := time.Now()
	return currentTime
}

func GetLastExecutionTime(currentTime time.Time) time.Time {
	// Get last execution of application

	pastTime := currentTime.Add(-12 * time.Hour)

	return pastTime
}