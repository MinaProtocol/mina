package hardfork

import (
	"fmt"
	"time"

	"github.com/tidwall/gjson"
)

// validateStringField validates that a string field exists and matches the expected value
func validateStringField(json, path, expected string) error {
	result := gjson.Get(json, path)
	if !result.Exists() {
		return fmt.Errorf("missing field: %s", path)
	}
	actual := result.String()
	if actual != expected {
		return fmt.Errorf("%s mismatch: expected %s, got %s", path, expected, actual)
	}
	return nil
}

// validateIntField validates that an integer field exists and matches the expected value
func validateIntField(json, path string, expected int) error {
	result := gjson.Get(json, path)
	if !result.Exists() {
		return fmt.Errorf("missing field: %s", path)
	}
	actual := result.Int()
	if actual != int64(expected) {
		return fmt.Errorf("%s mismatch: expected %d, got %d", path, expected, actual)
	}
	return nil
}

// validateInt64Field validates that an int64 field exists and matches the expected value
func validateInt64Field(json, path string, expected int64) error {
	result := gjson.Get(json, path)
	if !result.Exists() {
		return fmt.Errorf("missing field: %s", path)
	}
	actual := result.Int()
	if actual != expected {
		return fmt.Errorf("%s mismatch: expected %d, got %d", path, expected, actual)
	}
	return nil
}

// validateBoolField validates that a boolean field exists and matches the expected value
func validateBoolField(json, path string, expected bool) error {
	result := gjson.Get(json, path)
	if !result.Exists() {
		return fmt.Errorf("missing field: %s", path)
	}
	actual := result.Bool()
	if actual != expected {
		return fmt.Errorf("%s mismatch: expected %v, got %v", path, expected, actual)
	}
	return nil
}

// validateUnixTimestampField validates that a timestamp field matches the expected Unix timestamp
// The field must be stored as an RFC3339 formatted string
func validateUnixTimestampField(json, path string, expectedUnixTs int64) error {
	result := gjson.Get(json, path)
	if !result.Exists() {
		return fmt.Errorf("missing field: %s", path)
	}

	if result.Type != gjson.String {
		return fmt.Errorf("%s must be a string", path)
	}

	timestampStr := result.String()
	// Try parsing as RFC3339 timestamp
	t, err := time.Parse(time.RFC3339, timestampStr)
	if err != nil {
		// Also try a common variant with space instead of 'T'
		t, err = time.Parse("2006-01-02 15:04:05-07:00", timestampStr)
		if err != nil {
			return fmt.Errorf("%s is not a valid RFC3339 timestamp: %v", path, err)
		}
	}

	actualUnixTs := t.Unix()
	if actualUnixTs != expectedUnixTs {
		return fmt.Errorf("%s mismatch: expected %d, got %d", path, expectedUnixTs, actualUnixTs)
	}
	return nil
}

// validateObjectFields validates that an object contains only the expected fields
func (t *HardforkTest) validateObjectFields(json, path string, expectedFields []string) error {
	obj := gjson.Get(json, path)
	if !obj.Exists() {
		return fmt.Errorf("missing object: %s", path)
	}
	if !obj.IsObject() {
		return fmt.Errorf("%s is not an object", path)
	}

	// Create a map of expected fields for quick lookup
	expectedMap := make(map[string]bool)
	for _, field := range expectedFields {
		expectedMap[field] = true
	}

	// Check all fields in the object
	fieldCount := 0
	var unexpectedFields []string
	obj.ForEach(func(key, value gjson.Result) bool {
		fieldCount++
		fieldName := key.String()
		if !expectedMap[fieldName] {
			unexpectedFields = append(unexpectedFields, fieldName)
			t.Logger.Error("Unexpected field in %s: %s", path, fieldName)
		}
		return true // continue iteration
	})

	if len(unexpectedFields) > 0 {
		return fmt.Errorf("%s contains unexpected fields: %v", path, unexpectedFields)
	}

	if fieldCount != len(expectedFields) {
		return fmt.Errorf("%s should contain exactly %d field(s), found %d", path, len(expectedFields), fieldCount)
	}

	return nil
}

// validateRootObjectFields validates that the root-level JSON contains only expected fields
func (t *HardforkTest) validateRootObjectFields(json string, expectedFields []string) error {
	rootResult := gjson.Parse(json)
	if !rootResult.IsObject() {
		return fmt.Errorf("root is not an object")
	}

	// Create a map of expected fields for quick lookup
	expectedMap := make(map[string]bool)
	for _, field := range expectedFields {
		expectedMap[field] = true
	}

	// Check all fields in the root object
	fieldCount := 0
	var unexpectedFields []string
	rootResult.ForEach(func(key, value gjson.Result) bool {
		fieldCount++
		fieldName := key.String()
		if !expectedMap[fieldName] {
			unexpectedFields = append(unexpectedFields, fieldName)
			t.Logger.Error("Unexpected field in root object: %s", fieldName)
		}
		return true
	})

	if len(unexpectedFields) > 0 {
		return fmt.Errorf("root object contains unexpected fields: %v", unexpectedFields)
	}

	if fieldCount != len(expectedFields) {
		return fmt.Errorf("root object should contain exactly %d field(s), found %d", len(expectedFields), fieldCount)
	}

	return nil
}
