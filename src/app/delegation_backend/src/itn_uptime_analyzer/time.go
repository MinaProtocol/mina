package itn_uptime_analyzer

import (
	"time"
)


func GetCurrentTime() time.Time {
	currentTime := time.Now()
	return currentTime
}

// Get last execution time of application
func GetLastExecutionTime(currentTime time.Time) time.Time {

	pastTime := currentTime.Add(-12 * time.Hour)

	return pastTime
}
