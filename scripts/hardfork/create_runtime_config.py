#!/usr/bin/env python3

import json
import os
import sys
from datetime import datetime, timedelta


def create_runtime_config(fork_config_json=None, ledger_hashes_json=None, 
                         forking_from_config_json=None, genesis_timestamp=None,
                         seconds_per_slot=None):
    """Create runtime configuration for hardfork."""
    # Environment variables with defaults
    fork_config_json = fork_config_json or os.environ.get('FORK_CONFIG_JSON', 'fork_config.json')
    ledger_hashes_json = ledger_hashes_json or os.environ.get('LEDGER_HASHES_JSON', 'ledger_hashes.json')
    forking_from_config_json = forking_from_config_json or os.environ.get('FORKING_FROM_CONFIG_JSON', 'genesis_ledgers/mainnet.json')
    
    # If not given, the genesis timestamp is set to 10 mins into the future
    genesis_timestamp = genesis_timestamp or os.environ.get('GENESIS_TIMESTAMP')
    if not genesis_timestamp:
        future_time = datetime.utcnow() + timedelta(minutes=10)
        genesis_timestamp = future_time.strftime('%Y-%m-%dT%H:%M:%SZ')
    
    # Load config files
    try:
        with open(forking_from_config_json, 'r') as f:
            forking_from_config = json.load(f)
        
        with open(fork_config_json, 'r') as f:
            fork_config = json.load(f)
            
        with open(ledger_hashes_json, 'r') as f:
            ledger_hashes = json.load(f)
    except FileNotFoundError as e:
        print(f"Error: Could not find file {e.filename}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in file - {e}", file=sys.stderr)
        sys.exit(1)
    
    # Pull the original genesis timestamp from the pre-fork config file
    original_genesis_timestamp = forking_from_config['genesis']['genesis_state_timestamp']
    
    # Get offset from forking config
    offset = forking_from_config.get('proof', {}).get('fork', {}).get('global_slot_since_genesis', 0)
    if offset is None:
        offset = 0
    
    # Calculate time difference and convert to slots
    try:
        genesis_dt = datetime.fromisoformat(genesis_timestamp.replace('Z', '+00:00'))
        original_dt = datetime.fromisoformat(original_genesis_timestamp.replace('Z', '+00:00'))
        difference_in_seconds = int((genesis_dt - original_dt).total_seconds())
    except ValueError as e:
        print(f"Error: Invalid timestamp format - {e}", file=sys.stderr)
        sys.exit(1)
    
    # Default: mainnet currently uses 180s per slot
    seconds_per_slot = seconds_per_slot or int(os.environ.get('SECONDS_PER_SLOT', '180'))
    difference_in_slots = difference_in_seconds // seconds_per_slot
    
    slot = difference_in_slots + offset
    
    # Create the output configuration
    output_config = {
        "genesis": {
            "genesis_state_timestamp": genesis_timestamp
        },
        "proof": {
            "fork": {
                "state_hash": fork_config['proof']['fork']['state_hash'],
                "blockchain_length": fork_config['proof']['fork']['blockchain_length'],
                "global_slot_since_genesis": slot
            }
        },
        "ledger": {
            "add_genesis_winner": False,
            "hash": ledger_hashes[0]['ledger']['hash'],
            "s3_data_hash": ledger_hashes[0]['ledger']['s3_data_hash']
        },
        "epoch_data": {
            "staking": {
                "seed": fork_config['epoch_data']['staking']['seed'],
                "hash": ledger_hashes[0]['epoch_data']['staking']['hash'],
                "s3_data_hash": ledger_hashes[0]['epoch_data']['staking']['s3_data_hash']
            },
            "next": {
                "seed": fork_config['epoch_data']['next']['seed'],
                "hash": ledger_hashes[0]['epoch_data']['next']['hash'],
                "s3_data_hash": ledger_hashes[0]['epoch_data']['next']['s3_data_hash']
            }
        }
    }
    
    # Return JSON string (with minimal formatting to match jq -M output)
    return json.dumps(output_config, separators=(',', ':'))


def main():
    """Main entry point for command line usage."""
    result = create_runtime_config()
    print(result)


if __name__ == "__main__":
    main()