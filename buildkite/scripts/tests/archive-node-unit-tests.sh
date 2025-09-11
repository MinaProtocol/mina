#!/bin/bash

# Archive Node Unit Tests Script
#
# This script runs unit tests for the Mina archive node component with database setup.
# It must be executed from the repository root directory where 'dune-project' exists.
#
# USAGE:
#   ./archive-node-unit-tests.sh <user> <password> <db> <command_key>
#
# PARAMETERS:
#   user         - Database username for test database connection
#   password     - Database password for test database connection  
#   db           - Database name for archive node tests
#   command_key  - Unique identifier for coverage data upload
#
# PREREQUISITES:
#   - Must be run from repository root (where dune-project file exists)
#   - OPAM environment must be available
#   - Database setup script must exist at ./buildkite/scripts/setup-database-for-archive-node.sh
#   - Coverage upload script must exist at ./buildkite/scripts/upload-partial-coverage-data.sh
#
# WORKFLOW:
#   1. Validates script is run from correct directory
#   2. Validates all required parameters are provided
#   3. Sets up OPAM environment
#   4. Configures test database using provided credentials
#   5. Runs archive node unit tests via dune
#   6. Uploads partial coverage data for CI/CD pipeline
#
# EXIT CODES:
#   0 - Success
#   1 - Error (wrong directory, missing parameters, or test failure)
#
# ENVIRONMENT VARIABLES SET:
#   MINA_TEST_POSTGRES - Database connection string set by setup script

set -euo pipefail

if [[ ! -f dune-project ]]; then
    echo "Error: This script must be run from the root of the repository (where 'dune-project' exists)."
    exit 1
fi

user="$1"
password="$2"
db="$3"
command_key="$4"

if [[ -z "$user" || -z "$password" || -z "$db" || -z "$command_key" ]]; then
    echo "Usage: $0 <user> <password> <db> <command_key>"
    exit 1
fi

eval "$(opam config env)"

echo "Setting up database for archive node tests..."

source ./buildkite/scripts/setup-database-for-archive-node.sh ${user} ${password} ${db} 

echo "Database setup complete, accessible via $MINA_TEST_POSTGRES . Running archive node unit tests..."
dune runtest src/app/archive 

./buildkite/scripts/upload-partial-coverage-data.sh ${command_key} "dev"