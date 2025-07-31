#!/usr/bin/env python3

import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

# Import our test helper functions
from test_helper import (
    get_height, get_height_and_slot_of_earliest, get_fork_config,
    blocks, blocks_with_user_commands, latest_nonempty_block,
    IX_STATE_HASH, IX_HEIGHT, IX_SLOT, IX_NON_EMPTY, IX_CUR_EPOCH_HASH,
    IX_CUR_EPOCH_SEED, IX_NEXT_EPOCH_HASH, IX_NEXT_EPOCH_SEED,
    IX_STAGED_HASH, IX_SNARKED_HASH, IX_EPOCH
)


def run_command(cmd, check=True, capture_output=False, cwd=None):
    """Run a shell command."""
    if capture_output:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
        if check and result.returncode != 0:
            print(f"Command failed: {cmd}", file=sys.stderr)
            print(f"Error: {result.stderr}", file=sys.stderr)
            sys.exit(result.returncode)
        return result.stdout.strip() if result.stdout else ""
    else:
        result = subprocess.run(cmd, shell=True, cwd=cwd)
        if check and result.returncode != 0:
            print(f"Command failed: {cmd}", file=sys.stderr)
            sys.exit(result.returncode)
        return result.returncode


def stop_nodes(mina_exe):
    """Stop daemon nodes."""
    try:
        run_command(f'"{mina_exe}" client stop-daemon --daemon-port 10301', check=False)
    except:
        pass
    try:
        run_command(f'"{mina_exe}" client stop-daemon --daemon-port 10311', check=False)
    except:
        pass


def find_staking_hash(epoch, genesis_epoch_staking_hash, genesis_epoch_next_hash, epochs, last_snarked_hash_pe):
    """Find staking ledger hash corresponding to an epoch."""
    if epoch == 0:
        return genesis_epoch_staking_hash
    elif epoch == 1:
        return genesis_epoch_next_hash
    else:
        e_ = epoch - 2
        try:
            ix = epochs.index(e_)
            return last_snarked_hash_pe[ix]
        except ValueError:
            print(f"Assertion failed: last snarked ledger for epoch {e_} wasn't captured", file=sys.stderr)
            sys.exit(3)


def run_hardfork_test(main_mina_exe, main_runtime_genesis_ledger_exe, 
                     fork_mina_exe, fork_runtime_genesis_ledger_exe):
    """
    Run the complete hardfork test.
    
    Args:
        main_mina_exe: Path to main Mina executable
        main_runtime_genesis_ledger_exe: Path to main runtime genesis ledger executable
        fork_mina_exe: Path to fork Mina executable
        fork_runtime_genesis_ledger_exe: Path to fork runtime genesis ledger executable
    
    Returns:
        True if test passes, False otherwise
    """
    script_dir = Path(__file__).parent.absolute()
    
    # Environment variables with defaults
    slot_tx_end = int(os.environ.get('SLOT_TX_END', '30'))
    slot_chain_end = int(os.environ.get('SLOT_CHAIN_END', str(slot_tx_end + 8)))
    best_chain_query_from = int(os.environ.get('BEST_CHAIN_QUERY_FROM', '25'))
    main_slot = int(os.environ.get('MAIN_SLOT', '15'))
    fork_slot = int(os.environ.get('FORK_SLOT', '15'))
    main_delay = int(os.environ.get('MAIN_DELAY', '20'))
    fork_delay = int(os.environ.get('FORK_DELAY', '10'))
    
    # Executables are passed as parameters
    
    # 1. Node is started
    now_unix_ts = int(datetime.utcnow().timestamp())
    main_genesis_unix_ts = now_unix_ts - (now_unix_ts % 60) + (main_delay * 60)
    genesis_timestamp = datetime.fromtimestamp(main_genesis_unix_ts).strftime('%Y-%m-%d %H:%M:%S+00:00')
    os.environ['GENESIS_TIMESTAMP'] = genesis_timestamp
    
    # Start main network using library function
    from run_localnet import run_localnet
    
    print(f"Starting main network with {main_mina_exe}")
    bp_process, sw_process = run_localnet(
        mina_exe=main_mina_exe,
        tx_interval=str(main_slot),
        slot=main_slot,
        slot_tx_end=str(slot_tx_end),
        slot_chain_end=str(slot_chain_end),
        genesis_timestamp=genesis_timestamp
    )
    main_network_processes = (bp_process, sw_process)
    
    # Sleep until best chain query time
    sleep_time = main_slot * best_chain_query_from - (now_unix_ts % 60) + (main_delay * 60)
    print(f"Sleeping for {sleep_time} seconds until slot {best_chain_query_from}")
    time.sleep(sleep_time)
    
    try:
        # 2. Check that there are many blocks >50% of slots occupied
        block_height = get_height(10303)
        print(f"Block height is {block_height} at slot {best_chain_query_from}.")
        
        if (2 * block_height) < best_chain_query_from:
            print("Assertion failed: slot occupancy is below 50%", file=sys.stderr)
            stop_nodes(main_mina_exe)
            return False
        
        # Get first epoch data
        first_epoch_blocks = blocks(10303)
        first_epoch_ne_str = latest_nonempty_block(first_epoch_blocks)
        first_epoch_ne = first_epoch_ne_str.split(',')
        
        genesis_epoch_staking_hash = first_epoch_ne[3 + IX_CUR_EPOCH_HASH]
        genesis_epoch_next_hash = first_epoch_ne[3 + IX_NEXT_EPOCH_HASH]
        
        print(f"Genesis epoch staking/next hashes: {genesis_epoch_staking_hash}, {genesis_epoch_next_hash}")
        
        # Collect blocks from best_chain_query_from to slot_chain_end
        all_blocks = []
        for i in range(best_chain_query_from, slot_chain_end + 1):
            port = 10303 + 10 * (i % 2)  # Alternate between ports
            try:
                block_data = blocks(port)
                all_blocks.extend(block_data)
            except:
                pass  # Ignore errors, equivalent to '|| true'
            time.sleep(main_slot)
        
        last_ne_str = latest_nonempty_block(all_blocks)
        latest_ne = last_ne_str.split(',')
        
        # Parse latest non-empty block data
        max_slot = int(latest_ne[0])
        epochs_str = latest_ne[1]
        last_snarked_hash_pe_str = latest_ne[2]
        
        if epochs_str:
            epochs = [int(e) for e in epochs_str.split(':')]
            last_snarked_hash_pe = last_snarked_hash_pe_str.split(':')
        else:
            epochs = []
            last_snarked_hash_pe = []
        
        latest_ne = latest_ne[3:]  # Remove first 3 elements
        
        print(f"Last occupied slot of pre-fork chain: {max_slot}")
        if max_slot >= slot_chain_end:
            print(f"Assertion failed: block with slot {max_slot} created after slot chain end", file=sys.stderr)
            stop_nodes(main_mina_exe)
            return False
        
        latest_shash = latest_ne[IX_STATE_HASH]
        latest_height = int(latest_ne[IX_HEIGHT])
        latest_ne_slot = int(latest_ne[IX_SLOT])
        
        print(f"Latest non-empty block: {latest_shash}, height: {latest_height}, slot: {latest_ne_slot}")
        if latest_ne_slot >= slot_tx_end:
            print(f"Assertion failed: non-empty block with slot {latest_ne_slot} created after slot tx end", file=sys.stderr)
            stop_nodes(main_mina_exe)
            return False
        
        expected_fork_data = {
            "fork": {
                "blockchain_length": latest_height,
                "global_slot_since_genesis": latest_ne_slot,
                "state_hash": latest_shash
            },
            "next_seed": latest_ne[IX_NEXT_EPOCH_SEED],
            "staking_seed": latest_ne[IX_CUR_EPOCH_SEED]
        }
        
        # 4. Check that no new blocks are created
        time.sleep(60)  # Sleep 1 minute
        height1 = get_height(10303)
        time.sleep(300)  # Sleep 5 minutes
        height2 = get_height(10303)
        
        if (height2 - height1) > 0:
            print("Assertion failed: there should be no change in blockheight after slot chain end.", file=sys.stderr)
            stop_nodes(main_mina_exe)
            return False
        
        # 6. Transition root is extracted into a new runtime config
        fork_config = get_fork_config(10313)
        with open('localnet/fork_config.json', 'w') as f:
            json.dump(fork_config, f)
        
        # Wait until fork config is properly written
        while True:
            try:
                stat_result = os.stat('localnet/fork_config.json')
                if stat_result.st_size == 0:
                    raise ValueError("Empty file")
                
                with open('localnet/fork_config.json', 'r') as f:
                    content = f.read(4)
                    if content == "null":
                        raise ValueError("Null content")
                break
            except:
                print("Failed to fetch fork config", file=sys.stderr)
                time.sleep(60)
                fork_config = get_fork_config(10313)
                with open('localnet/fork_config.json', 'w') as f:
                    json.dump(fork_config, f)
        
        # 7. Runtime config is converted with a script to have only ledger hashes in the config
        stop_nodes(main_mina_exe)
        
        # Verify fork data
        with open('localnet/fork_config.json', 'r') as f:
            saved_fork_config = json.load(f)
        
        fork_data = {
            "fork": saved_fork_config['proof']['fork'],
            "next_seed": saved_fork_config['epoch_data']['next']['seed'],
            "staking_seed": saved_fork_config['epoch_data']['staking']['seed']
        }
        
        if json.dumps(fork_data, sort_keys=True, separators=(',', ':')) != json.dumps(expected_fork_data, sort_keys=True, separators=(',', ':')):
            print("Assertion failed: unexpected fork data", file=sys.stderr)
            return False
        
        # Generate prefork ledgers
        run_command(f'"{main_runtime_genesis_ledger_exe}" --config-file localnet/fork_config.json --genesis-dir localnet/prefork_hf_ledgers --hash-output-file localnet/prefork_hf_ledger_hashes.json')
        
        # Calculate expected hashes
        slot_tx_end_epoch = latest_ne_slot // 48
        expected_staking_hash = find_staking_hash(slot_tx_end_epoch, genesis_epoch_staking_hash, genesis_epoch_next_hash, epochs, last_snarked_hash_pe)
        expected_next_hash = find_staking_hash(slot_tx_end_epoch + 1, genesis_epoch_staking_hash, genesis_epoch_next_hash, epochs, last_snarked_hash_pe)
        
        expected_prefork_hashes = {
            "epoch_data": {
                "next": {"hash": expected_next_hash},
                "staking": {"hash": expected_staking_hash}
            },
            "ledger": {"hash": latest_ne[IX_STAGED_HASH]}
        }
        
        # Verify prefork hashes
        with open('localnet/prefork_hf_ledger_hashes.json', 'r') as f:
            prefork_hashes_data = json.load(f)
        
        prefork_hashes = {
            "epoch_data": {
                "staking": {"hash": prefork_hashes_data['epoch_data']['staking']['hash']},
                "next": {"hash": prefork_hashes_data['epoch_data']['next']['hash']}
            },
            "ledger": {"hash": prefork_hashes_data['ledger']['hash']}
        }
        
        if json.dumps(prefork_hashes, sort_keys=True, separators=(',', ':')) != json.dumps(expected_prefork_hashes, sort_keys=True, separators=(',', ':')):
            print("Assertion failed: unexpected ledgers in fork_config", file=sys.stderr)
            print(f"Expected: {json.dumps(expected_prefork_hashes, sort_keys=True, separators=(',', ':'))}", file=sys.stderr)
            print(f"Actual: {json.dumps(prefork_hashes, sort_keys=True, separators=(',', ':'))}", file=sys.stderr)
            return False
        
        # Clean and create hf_ledgers directory
        if os.path.exists('localnet/hf_ledgers'):
            shutil.rmtree('localnet/hf_ledgers')
        os.makedirs('localnet/hf_ledgers')
        
        # Generate fork ledgers
        run_command(f'"{fork_runtime_genesis_ledger_exe}" --config-file localnet/fork_config.json --genesis-dir localnet/hf_ledgers --hash-output-file localnet/hf_ledger_hashes.json')
        
        # Create fork configuration
        now_unix_ts = int(datetime.utcnow().timestamp())
        fork_genesis_unix_ts = now_unix_ts - (now_unix_ts % 60) + (fork_delay * 60)
        fork_genesis_timestamp = datetime.fromtimestamp(fork_genesis_unix_ts).strftime('%Y-%m-%d %H:%M:%S+00:00')
        
        # Generate config using library function
        from create_runtime_config import create_runtime_config
        
        config_json = create_runtime_config(
            fork_config_json='localnet/fork_config.json',
            ledger_hashes_json='localnet/hf_ledger_hashes.json',
            forking_from_config_json='localnet/config/base.json',
            genesis_timestamp=fork_genesis_timestamp,
            seconds_per_slot=main_slot
        )
        
        with open('localnet/config.json', 'w') as f:
            f.write(config_json)
        
        # Verify modified fork data
        expected_genesis_slot = (fork_genesis_unix_ts - main_genesis_unix_ts) // main_slot
        expected_modified_fork_data = {
            "blockchain_length": latest_height,
            "global_slot_since_genesis": expected_genesis_slot,
            "state_hash": latest_shash
        }
        
        with open('localnet/config.json', 'r') as f:
            config_data = json.load(f)
        
        modified_fork_data = config_data['proof']['fork']
        
        if json.dumps(modified_fork_data, sort_keys=True, separators=(',', ':')) != json.dumps(expected_modified_fork_data, sort_keys=True, separators=(',', ':')):
            print("Assertion failed: unexpected modified fork data", file=sys.stderr)
            return False
        
        # Wait for main network processes to finish
        bp_process.wait()
        sw_process.wait()
        
        print("Config for the fork is correct, starting a new network")
        
        # 8. Node is shutdown and restarted with mina-fork and the config from previous step
        print(f"Starting fork network with {fork_mina_exe}")
        fork_bp_process, fork_sw_process = run_localnet(
            mina_exe=fork_mina_exe,
            delay_min=fork_delay,
            tx_interval=str(fork_slot),
            slot=fork_slot,
            custom_conf='localnet/config.json',
            genesis_ledger_dir='localnet/hf_ledgers'
        )
        
        time.sleep(fork_delay * 60)
        
        # Check earliest block
        earliest_str = ""
        while not earliest_str or earliest_str == ",":
            try:
                earliest_str = get_height_and_slot_of_earliest(10303)
            except:
                earliest_str = ""
            time.sleep(fork_slot)
        
        earliest_height, earliest_slot = map(int, earliest_str.split(','))
        
        if earliest_height != (latest_height + 1):
            print(f"Assertion failed: unexpected block height {earliest_height} at the beginning of the fork", file=sys.stderr)
            stop_nodes(fork_mina_exe)
            return False
        
        if earliest_slot < expected_genesis_slot:
            print(f"Assertion failed: unexpected slot {earliest_slot} at the beginning of the fork", file=sys.stderr)
            stop_nodes(fork_mina_exe)
            return False
        
        # 9. Check that network eventually creates some blocks
        time.sleep(fork_slot * 10)
        height1 = get_height(10303)
        if height1 == 0:
            print(f"Assertion failed: block height {height1} should be greater than 0.", file=sys.stderr)
            stop_nodes(fork_mina_exe)
            return False
        
        print("Blocks are produced.")
        
        # Wait and check that there are blocks created with >50% occupancy and there are transactions in last 10 blocks
        all_blocks_empty = True
        for i in range(1, 11):
            time.sleep(fork_slot)
            try:
                usercmds = blocks_with_user_commands(10303)
                if usercmds != 0:
                    all_blocks_empty = False
            except:
                pass  # Ignore errors
        
        if all_blocks_empty:
            print("Assertion failed: all blocks in fork chain are empty", file=sys.stderr)
            stop_nodes(fork_mina_exe)
            return False
        
        stop_nodes(fork_mina_exe)
        fork_bp_process.wait()
        fork_sw_process.wait()
        
        print("Hardfork test completed successfully!")
        return True
        
    except Exception as e:
        print(f"Test failed with error: {e}", file=sys.stderr)
        try:
            stop_nodes(main_mina_exe)
            stop_nodes(fork_mina_exe)
        except:
            pass
        return False
    except KeyboardInterrupt:
        print("\nTest interrupted", file=sys.stderr)
        try:
            stop_nodes(main_mina_exe)
            stop_nodes(fork_mina_exe)
            if 'bp_process' in locals():
                bp_process.terminate()
                sw_process.terminate()
            if 'fork_bp_process' in locals():
                fork_bp_process.terminate()
                fork_sw_process.terminate()
        except:
            pass
        return False


def main():
    """Main entry point for command line usage."""
    # Command line arguments
    if len(sys.argv) != 5:
        print("Usage: test.py MAIN_MINA_EXE MAIN_RUNTIME_GENESIS_LEDGER_EXE FORK_MINA_EXE FORK_RUNTIME_GENESIS_LEDGER_EXE", file=sys.stderr)
        sys.exit(1)
    
    main_mina_exe = sys.argv[1]
    main_runtime_genesis_ledger_exe = sys.argv[2]
    fork_mina_exe = sys.argv[3]
    fork_runtime_genesis_ledger_exe = sys.argv[4]
    
    success = run_hardfork_test(
        main_mina_exe=main_mina_exe,
        main_runtime_genesis_ledger_exe=main_runtime_genesis_ledger_exe,
        fork_mina_exe=fork_mina_exe,
        fork_runtime_genesis_ledger_exe=fork_runtime_genesis_ledger_exe
    )
    
    if not success:
        sys.exit(3)


if __name__ == "__main__":
    main()