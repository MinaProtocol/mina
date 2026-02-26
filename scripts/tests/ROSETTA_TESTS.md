# Rosetta Test Scripts Documentation

This document provides comprehensive documentation for all Rosetta API testing scripts located in `./scripts/tests/`. These scripts are designed to test the Mina Protocol Rosetta API implementation for functionality, performance, and reliability.

## Overview

The Rosetta API test suite consists of four main scripts that work together to provide comprehensive testing capabilities:

- **rosetta-helper.sh**: Core helper functions and utilities
- **rosetta-sanity.sh**: Basic functionality and sanity testing
- **rosetta-load.sh**: Performance and load testing
- **rosetta-connectivity.sh**: End-to-end connectivity testing

## Scripts Documentation

### 1. rosetta-helper.sh

**Purpose**: Core helper functions and utilities shared across all Rosetta test scripts.

**Location**: `scripts/tests/rosetta-helper.sh`

**Key Features**:
- Common HTTP request handling with standardized headers
- Test assertion framework for validating API responses
- Network synchronization utilities
- Individual test functions for each Rosetta API endpoint

**Main Functions**:

#### `assert(response, query, success_message, error_message)`
- **Purpose**: Validates API responses using jq queries
- **Parameters**: 
  - `response`: Raw API response 
  - `query`: jq query to validate response
  - `success_message`: Message shown on success
  - `error_message`: Message shown on failure
- **Usage**: Core validation function used by all test endpoints

#### `wait_for_sync(test_data, timeout)`
- **Purpose**: Waits for Rosetta API to sync with the blockchain
- **Parameters**:
  - `test_data`: Reference to test configuration array
  - `timeout`: Maximum wait time in seconds
- **Behavior**: Polls `/network/status` endpoint until sync status is "Synced"
- **Exit**: Exits with code 1 if timeout is reached

#### `test_network_status(test_data)`
- **Purpose**: Tests `/network/status` endpoint
- **Validation**: Ensures sync status is "Synced"
- **Location**: `scripts/tests/rosetta-helper.sh:57-63`

#### `test_network_options(test_data)`
- **Purpose**: Tests `/network/options` endpoint  
- **Validation**: Verifies Rosetta version is 1.4.9
- **Location**: `scripts/tests/rosetta-helper.sh:65-71`

#### `test_block(test_data)`
- **Purpose**: Tests `/block` endpoint for specific block retrieval
- **Validation**: Confirms returned block hash matches requested hash
- **Location**: `scripts/tests/rosetta-helper.sh:73-79`

#### `test_account_balance(test_data)`
- **Purpose**: Tests `/account/balance` endpoint
- **Validation**: Ensures balance structure contains MINA currency symbol
- **Location**: `scripts/tests/rosetta-helper.sh:81-87`

#### `test_payment_transaction(test_data)`
- **Purpose**: Tests `/search/transactions` endpoint for payment transactions
- **Validation**: Confirms transaction hash matches requested payment transaction
- **Location**: `scripts/tests/rosetta-helper.sh:89-103`

#### `test_zkapp_transaction(test_data)`
- **Purpose**: Tests `/search/transactions` endpoint for zkApp transactions
- **Validation**: Confirms transaction hash matches requested zkApp transaction
- **Location**: `scripts/tests/rosetta-helper.sh:105-119`

### 2. rosetta-sanity.sh

**Purpose**: Basic functionality testing of Rosetta API endpoints with predefined test data.

**Location**: `scripts/tests/rosetta-sanity.sh`

**Usage**:
```bash
./rosetta-sanity.sh [--network mainnet|devnet] [--address <address>] [--daemon-graphql-address <address>] [--wait-for-sync] [--timeout <seconds>]
```

**Command-line Options**:
- `--network`: Target network (mainnet or devnet, default: mainnet)
- `--address`: Override Rosetta API endpoint address
- `--daemon-graphql-address`: Override daemon GraphQL endpoint address (default: http://localhost:3085/graphql)
- `--wait-for-sync`: Wait for Rosetta to sync before running tests
- `--timeout`: Sync timeout in seconds (default: 900)

**Test Data Configuration**:

#### Mainnet Test Data:
- **Network ID**: mainnet
- **Default Address**: http://rosetta-mainnet.gcp.o1test.net
- **Test Block**: 3NLaE5ygWrgssHjchYR7auQTZHveVV5au5cv5VhbWWYPdbdSm4FA
- **Test Account**: B62qrQKS9ghd91shs73TCmBJRW9GzvTJK443DPx2YbqcyoLc56g1ny9
- **Payment TX**: 5JvGLZ22Pt5co9ikFhHVcewsrGNx9xwPx16oKvJ42oujZRU7Ymfh
- **zkApp TX**: 5Ju42hSKHMPFFuH2iar8V1scHdWET2TV8ocaazRbEea5yFWDe7RH

#### Devnet Test Data:
- **Network ID**: devnet  
- **Default Address**: http://rosetta-devnet.gcp.o1test.net
- **Test Block**: 3NLX177ZPMRfgYX6sX6tEnhb97gvjWKiivk9Fk2q8M6vHHjAQPYk
- **Test Account**: B62qizKV19RgCtdosaEnoJRF72YjTSDyfJ5Nrdu8ygKD3q2eZcqUp7B
- **Payment TX**: 5Jumdze53X3k8rVaNQpJKdt8voGXRgVcFBZugg21FE1K7QkJBhLb
- **zkApp TX**: 5JuJuyKtrMvxGroWyNE3sxwpuVsupvj7SA8CDX4mqWms4ZZT4Arz

**Test Sequence**:
1. Network status endpoint validation
2. Network options endpoint validation  
3. Block retrieval testing
4. Account balance querying
5. Payment transaction search
6. zkApp transaction search

**Example Usage**:
```bash
# Basic mainnet testing
./rosetta-sanity.sh --network mainnet

# Devnet testing with custom endpoint
./rosetta-sanity.sh --network devnet --address http://localhost:3087

# Testing with custom Rosetta and daemon endpoints
./rosetta-sanity.sh --network devnet --address http://localhost:3087 --daemon-graphql-address http://localhost:3085/graphql

# Wait for sync before testing
./rosetta-sanity.sh --network mainnet --wait-for-sync --timeout 1200
```

### 3. rosetta-load.sh

**Purpose**: Comprehensive performance and load testing of Rosetta API with configurable test intervals and database-driven test data.

**Location**: `scripts/tests/rosetta-load.sh`

**Key Features**:
- **Database Integration**: Loads real test data from PostgreSQL archive database
- **Configurable Intervals**: Independent timing control for each test type
- **Performance Monitoring**: Real-time TPS tracking and memory usage reporting
- **Multiple Stop Conditions**: Duration-based or request-count-based termination
- **Precise Timing**: High-precision scheduling prevents timing drift

**Usage**:
```bash
./rosetta-load.sh [options]
```

**Command-line Options**:

#### Network Configuration:
- `--network <network>`: Target network (mainnet or devnet, default: mainnet)
- `--address <address>`: Rosetta API endpoint (default: http://rosetta-mainnet.gcp.o1test.net)
- `--db-conn-str <conn_str>`: PostgreSQL connection string

#### Test Intervals (seconds):
- `--status-interval N`: Network status API call interval (default: 10)
- `--options-interval N`: Network options API call interval (default: 10)  
- `--block-interval N`: Block retrieval API call interval (default: 2)
- `--account-balance-interval N`: Account balance API call interval (default: 1)
- `--payment-tx-interval N`: Payment transaction API call interval (default: 2)
- `--zkapp-tx-interval N`: zkApp transaction API call interval (default: 1)

#### Stop Conditions:
- `--duration <seconds>`: Run for specified duration
- `--max-requests N`: Stop after N total requests

**Database Integration**:

The script loads realistic test data from the archive database:

#### `load_blocks_from_db(conn_str)`
- **Query**: `SELECT state_hash FROM blocks LIMIT 100`
- **Purpose**: Loads block hashes for block retrieval testing
- **Storage**: `load[blocks]` array

#### `load_accounts_from_db(conn_str)`  
- **Query**: `SELECT value FROM public_keys LIMIT 100`
- **Purpose**: Loads account public keys for balance testing
- **Storage**: `load[accounts]` array

#### `load_payment_transactions_from_db(conn_str)`
- **Query**: `SELECT hash FROM user_commands LIMIT 100` 
- **Purpose**: Loads payment transaction hashes for transaction testing
- **Storage**: `load[payment_transactions]` array

#### `load_zkapp_transactions_from_db(conn_str)`
- **Query**: `SELECT hash FROM zkapp_commands LIMIT 100`
- **Purpose**: Loads zkApp transaction hashes for zkApp testing  
- **Storage**: `load[zkapp_transactions]` array

**Performance Monitoring**:

#### `print_memory_usage()`
- **Monitors**: PostgreSQL, mina-archive, mina-rosetta processes
- **Metrics**: RSS memory usage in MB
- **Frequency**: Every 10 seconds during load test

#### `print_load_test_statistics()`
- **Current TPS**: Requests per second since last report
- **Average TPS**: Overall test average transactions per second
- **Total Requests**: Cumulative request count
- **Memory Usage**: Process memory consumption

**Main Load Test Function**:

#### `run_all_tests_custom_intervals()`
- **Precision Timing**: Uses floating-point timestamps to prevent drift
- **Random Selection**: Randomly picks test data for each request
- **Concurrent Testing**: All test types run simultaneously at their configured intervals
- **Stop Conditions**: Monitors duration and request limits continuously

**Example Usage**:
```bash
# Basic load test for 5 minutes
./rosetta-load.sh --network mainnet --duration 300

# High-frequency testing with custom intervals
./rosetta-load.sh --network devnet --block-interval 1 --account-balance-interval 0.5

# Database load test with request limit
./rosetta-load.sh --db-conn-str "postgresql://user:pass@localhost/archive" --max-requests 10000

# Custom endpoint load testing
./rosetta-load.sh --address http://localhost:3087 --duration 600 --network devnet
```

### 4. rosetta-connectivity.sh

**Purpose**: End-to-end connectivity testing using Docker containers, combining sanity and load testing in a controlled environment.

**Location**: `scripts/tests/rosetta-connectivity.sh`

**Key Features**:
- **Docker Integration**: Automatically spins up Rosetta containers
- **Network Support**: Both mainnet and devnet configurations  
- **Optional Load Testing**: Can include performance testing
- **Automatic Cleanup**: Handles container lifecycle management
- **Volume Mounting**: Mounts repository for script access

**Usage**:
```bash
./rosetta-connectivity.sh -t <docker-tag> [-n network] [--run-load-test]
```

**Command-line Options**:
- `-t, --tag <tag>`: Docker image tag (required)
- `-n, --network <network>`: Network configuration (devnet or mainnet, default: devnet)
- `--run-load-test`: Enable load testing (default: false)  
- `--timeout <seconds>`: Sync timeout duration (default: 900)
- `-h, --help`: Show help information

**Docker Configuration**:
- **Image**: gcr.io/o1labs-192920/mina-rosetta:$TAG-$NETWORK
- **Port Mapping**: 3087:3087 (Rosetta API port)
- **Volume Mount**: `.:/workdir` (repository access)
- **Environment**: MINA_NETWORK set to specified network

**Test Execution Flow**:
1. **Container Startup**: Launches Docker container with specified tag and network
2. **Initialization Wait**: 5-second delay for container startup  
3. **Sanity Testing**: Runs rosetta-sanity.sh with sync wait
4. **Load Testing** (optional): Executes 600-second load test
5. **Cleanup**: Stops and removes container (even on failure)

**Trap Handling**:
- **Error Handling**: `trap stop_docker ERR` ensures cleanup on script failure
- **Container Management**: Stops and removes container automatically

**Load Test Configuration** (when enabled):
- **Duration**: 600 seconds (10 minutes)
- **Database**: postgres://pguser:pguser@localhost:5432/archive  
- **Endpoint**: http://localhost:3087
- **Execution Context**: Inside Docker container via `docker exec`

**Example Usage**:
```bash
# Basic connectivity test for devnet
./rosetta-connectivity.sh --tag 3.0.3-bullseye-devnet --network devnet

# Mainnet connectivity with load testing  
./rosetta-connectivity.sh --tag 3.0.3-bullseye-mainnet --network mainnet --run-load-test

# Custom timeout for slow environments
./rosetta-connectivity.sh --tag 3.0.3-bullseye-testnet-generic --timeout 1800
```

## Integration and Dependencies

### Script Relationships:
```
rosetta-connectivity.sh
├── Launches Docker container
├── Calls rosetta-sanity.sh
│   └── Sources rosetta-helper.sh
└── Optionally calls rosetta-load.sh  
    └── Sources rosetta-helper.sh
```

### External Dependencies:
- **curl**: HTTP request execution
- **jq**: JSON response parsing and validation
- **psql**: PostgreSQL database connectivity (load testing)
- **docker**: Container management (connectivity testing)
- **bc**: Floating-point arithmetic (load testing)

### Database Schema Dependencies (Load Testing):
- **blocks table**: `state_hash` column
- **public_keys table**: `value` column  
- **user_commands table**: `hash` column
- **zkapp_commands table**: `hash` column

## Testing Scenarios

### 1. Quick Sanity Check:
```bash
./rosetta-sanity.sh --network devnet --address http://localhost:3087
```

### 2. Full Load Testing:
```bash  
./rosetta-load.sh --network mainnet --duration 1800 --db-conn-str "postgresql://user:pass@host/db"
```

### 3. Complete E2E Testing:
```bash
./rosetta-connectivity.sh --tag latest-tag --network mainnet --run-load-test
```

### 4. Custom Performance Testing:
```bash
./rosetta-load.sh --block-interval 0.5 --account-balance-interval 0.2 --max-requests 50000
```

## Configuration Files Location

The scripts reference these test data configurations:
- **Mainnet endpoints**: Hard-coded in rosetta-sanity.sh:10-13
- **Devnet endpoints**: Hard-coded in rosetta-sanity.sh:15-21
- **Default intervals**: Defined in rosetta-load.sh:34-59
- **Database queries**: Defined in rosetta-load.sh:250-308

## Error Handling and Exit Codes

### Common Exit Codes:
- **0**: Success
- **1**: General failure (assertion failed, timeout reached, invalid parameters)

### Error Sources:
- **API Assertion Failures**: Wrong response format or values
- **Network Connectivity**: Cannot reach Rosetta endpoint
- **Database Connectivity**: Cannot connect to PostgreSQL (load testing)
- **Docker Issues**: Container startup or management problems (connectivity testing)
- **Timeout Conditions**: Sync timeout or test duration limits

## Performance Considerations

### Load Testing Recommendations:
- **Start Conservative**: Begin with default intervals and increase frequency gradually
- **Monitor Resources**: Watch memory usage of database and Rosetta processes  
- **Database Connection**: Ensure PostgreSQL can handle concurrent query load
- **Network Bandwidth**: Consider network capacity for high-frequency testing

### Typical Performance Metrics:
- **Low Load**: 1-10 TPS sustainable indefinitely
- **Medium Load**: 10-50 TPS for extended periods
- **High Load**: 50+ TPS for stress testing scenarios

This documentation provides comprehensive coverage of all Rosetta testing scripts and their capabilities for validating Mina Protocol's Rosetta API implementation.