package hardfork

import (
	"fmt"

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
