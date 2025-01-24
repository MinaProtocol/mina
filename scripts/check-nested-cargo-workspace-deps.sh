#!/bin/bash

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Install it to use this script."
  exit 1
fi

# Paths to the root and nested Cargo.toml files
ROOT_TOML="Cargo.toml"
NESTED_TOML="src/lib/crypto/proof-systems/Cargo.toml"

# Function to extract workspace dependencies and their versions
extract_workspace_dependencies() {
  local cargo_toml_path="$1"

  # Run cargo metadata for the given workspace
  cargo metadata --format-version 1 --no-deps --manifest-path "$cargo_toml_path" | jq -r '.packages[].dependencies[] | select(.kind == null) | "\(.name) \(.req)"' | sort | uniq
}

# Extract dependencies for both workspaces
ROOT_DEPS=$(extract_workspace_dependencies "$ROOT_TOML")
NESTED_DEPS=$(extract_workspace_dependencies "$NESTED_TOML")

# Create temporary files for dependency lists
ROOT_TEMP=$(mktemp)
NESTED_TEMP=$(mktemp)

echo "$ROOT_DEPS" | sort > "$ROOT_TEMP"
echo "$NESTED_DEPS" | sort > "$NESTED_TEMP"

# Compare only dependencies that are in both files
COMMON_DEPS=$(comm -12 <(awk '{print $1}' "$ROOT_TEMP") <(awk '{print $1}' "$NESTED_TEMP"))

# Check for mismatched versions
MISMATCHES=()
for dep in $COMMON_DEPS; do
  ROOT_VERSION=$(grep "^$dep " "$ROOT_TEMP" | awk '{print $2}')
  NESTED_VERSION=$(grep "^$dep " "$NESTED_TEMP" | awk '{print $2}')
  if [[ "$ROOT_VERSION" != "$NESTED_VERSION" ]]; then
    MISMATCHES+=("$dep (root: $ROOT_VERSION, nested: $NESTED_VERSION)")
  fi
done

# Clean up temporary files
rm "$ROOT_TEMP" "$NESTED_TEMP"

# Output results
if [[ ${#MISMATCHES[@]} -eq 0 ]]; then
  echo "All common dependencies match between the root and nested Cargo.toml files."
  exit 0
else
  echo "Dependency version mismatches found in common dependencies:"
  for mismatch in "${MISMATCHES[@]}"; do
    echo "- $mismatch"
  done
  exit 1
fi
