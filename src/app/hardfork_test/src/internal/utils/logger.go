package utils

import (
	"log"
	"os"
	"time"
)

// Logger provides logging functionality
type Logger struct {
	infoLogger  *log.Logger
	errorLogger *log.Logger
	debugLogger *log.Logger
	isDebug     bool
}

// NewLogger creates a new logger
func NewLogger() *Logger {
	isDebug := os.Getenv("DEBUG") == "1"
	
	return &Logger{
		infoLogger:  log.New(os.Stdout, "INFO: ", log.LstdFlags),
		errorLogger: log.New(os.Stderr, "ERROR: ", log.LstdFlags),
		debugLogger: log.New(os.Stdout, "DEBUG: ", log.LstdFlags),
		isDebug:     isDebug,
	}
}

// Info logs an informational message
func (l *Logger) Info(format string, v ...interface{}) {
	l.infoLogger.Printf(format, v...)
}

// Error logs an error message
func (l *Logger) Error(format string, v ...interface{}) {
	l.errorLogger.Printf(format, v...)
}

// Debug logs a debug message if debug mode is enabled
func (l *Logger) Debug(format string, v ...interface{}) {
	if l.isDebug {
		l.debugLogger.Printf(format, v...)
	}
}

// Timestamp returns the current time in RFC3339 format
func Timestamp() string {
	return time.Now().Format(time.RFC3339)
}
