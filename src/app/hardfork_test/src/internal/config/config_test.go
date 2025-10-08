package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestValidateExecutable(t *testing.T) {
	// Create a temporary directory for our test files
	tempDir, err := os.MkdirTemp("", "executable_test")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Test cases
	testCases := []struct {
		name        string
		setup       func() string
		expectError bool
		expectedErr error
	}{
		{
			name: "Executable file",
			setup: func() string {
				path := filepath.Join(tempDir, "exec_file")
				if err := os.WriteFile(path, []byte("#!/bin/bash\necho test"), 0755); err != nil {
					t.Fatalf("Failed to create executable file: %v", err)
				}
				return path
			},
			expectError: false,
		},
		{
			name: "Non-executable file",
			setup: func() string {
				path := filepath.Join(tempDir, "non_exec_file")
				if err := os.WriteFile(path, []byte("#!/bin/bash\necho test"), 0644); err != nil {
					t.Fatalf("Failed to create non-executable file: %v", err)
				}
				return path
			},
			expectError: true,
			expectedErr: ErrNotExecutable,
		},
		{
			name: "Non-existent file",
			setup: func() string {
				return filepath.Join(tempDir, "non_existent_file")
			},
			expectError: true,
			expectedErr: ErrFileNotExists,
		},
		{
			name: "Directory instead of file",
			setup: func() string {
				path := filepath.Join(tempDir, "dir")
				if err := os.Mkdir(path, 0755); err != nil {
					t.Fatalf("Failed to create directory: %v", err)
				}
				return path
			},
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			path := tc.setup()
			err := validateExecutable(path)

			if tc.expectError && err == nil {
				t.Errorf("Expected error but got nil")
			}

			if !tc.expectError && err != nil {
				t.Errorf("Expected no error but got: %v", err)
			}

			if tc.expectedErr != nil && err != tc.expectedErr {
				t.Errorf("Expected error %v but got %v", tc.expectedErr, err)
			}
		})
	}
}
