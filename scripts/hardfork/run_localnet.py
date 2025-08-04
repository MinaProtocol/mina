#!/usr/bin/env python3

import argparse
import json
import os
import random
import shutil
import subprocess
import sys
import signal
import time
from datetime import datetime, timedelta
from pathlib import Path


def setup_signal_handlers():
    """Set up signal handlers to clean up child processes."""
    def signal_handler(sig, frame):
        print("\nReceived interrupt, cleaning up...")
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)


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


def run_localnet(mina_exe=None, tx_interval=None, delay_min=None, slot=None,
                develop=False, custom_conf=None, slot_tx_end=None, slot_chain_end=None,
                genesis_ledger_dir=None, genesis_timestamp=None, keys=None):
    """
    Run local Mina network with two nodes.
    
    Returns tuple of (bp_process, sw_process) - the two subprocess handles.
    """
    # Set environment variables
    os.environ['MINA_LIBP2P_PASS'] = ''
    os.environ['MINA_PRIVKEY_PASS'] = ''
    
    # Get script directory
    script_dir = Path(__file__).parent.absolute()
    
    # Default values from environment or defaults
    tx_interval = tx_interval or os.environ.get('TX_INTERVAL', '30s')
    delay_min = delay_min if delay_min is not None else int(os.environ.get('DELAY_MIN', '20'))
    slot = slot if slot is not None else int(os.environ.get('SLOT', '30'))
    mina_exe = mina_exe or os.environ.get('MINA_EXE', 'mina')
    genesis_ledger_dir = genesis_ledger_dir or os.environ.get('GENESIS_LEDGER_DIR', '')
    slot_tx_end = slot_tx_end or os.environ.get('SLOT_TX_END', '')
    slot_chain_end = slot_chain_end or os.environ.get('SLOT_CHAIN_END', '')
    keys = keys or []
    
    # Set configuration suffix
    conf_suffix = '.develop' if develop else os.environ.get('CONF_SUFFIX', '')
    custom_conf = custom_conf or os.environ.get('CUSTOM_CONF', '')
    
    # Validate arguments
    if conf_suffix and custom_conf:
        raise ValueError("Can't use both develop and config options")
    
    # Check mina command exists
    if shutil.which(mina_exe) is None:
        raise RuntimeError("No 'mina' executable found")
    
    # Genesis timestamp calculation
    genesis_timestamp = genesis_timestamp or os.environ.get('GENESIS_TIMESTAMP')
    if not genesis_timestamp:
        now = datetime.now()
        # Round down to minute and add delay
        calculated_time = now.replace(second=0, microsecond=0) + timedelta(minutes=delay_min)
        genesis_timestamp = calculated_time.strftime('%Y-%m-%d %H:%M:%S+00:00')
    
    ##########################################################
    # Generate configuration in localnet/config
    ##########################################################
    
    conf_dir = Path('localnet/config')
    conf_dir.mkdir(parents=True, exist_ok=True)
    conf_dir.chmod(0o700)
    
    # Generate keypairs if they don't exist
    bp_key = conf_dir / 'bp'
    if not bp_key.exists():
        run_command(f'"{mina_exe}" advanced generate-keypair --privkey-path {bp_key}')
    
    # Generate libp2p keypairs
    libp2p_1 = conf_dir / 'libp2p_1'
    libp2p_2 = conf_dir / 'libp2p_2'
    
    run_command(f'"{mina_exe}" libp2p generate-keypair --privkey-path {libp2p_1}')
    run_command(f'"{mina_exe}" libp2p generate-keypair --privkey-path {libp2p_2}')
    
    # Generate ledger if needed
    ledger_json = conf_dir / 'ledger.json'
    if not custom_conf and not ledger_json.exists():
        bp_pub_content = (conf_dir / 'bp.pub').read_text().strip()
        ledger_cmd = f'cd {conf_dir} && "{script_dir}/../prepare-test-ledger.sh" -c 100000 -b 1000000 "{bp_pub_content}" > ledger.json'
        run_command(ledger_cmd)
    
    # Create base configuration
    base_config = {
        "genesis": {
            "slots_per_epoch": 48,
            "k": 10,
            "grace_period_slots": 3,
            "genesis_state_timestamp": genesis_timestamp
        },
        "proof": {
            "work_delay": 1,
            "level": "full",
            "transaction_capacity": {"2_to_the": 2},
            "block_window_duration_ms": slot * 1000
        }
    }
    
    # Add slot ends if specified
    if slot_tx_end:
        base_config["daemon"] = base_config.get("daemon", {})
        base_config["daemon"]["slot_tx_end"] = int(slot_tx_end)
    if slot_chain_end:
        base_config["daemon"] = base_config.get("daemon", {})
        base_config["daemon"]["slot_chain_end"] = int(slot_chain_end)
    
    with open(conf_dir / 'base.json', 'w') as f:
        json.dump(base_config, f, separators=(',', ':'))
    
    # Create daemon configuration
    daemon_config_file = conf_dir / f'daemon{conf_suffix}.json'
    if not custom_conf:
        with open(ledger_json, 'r') as f:
            ledger_data = json.load(f)
        daemon_config = {"ledger": {"accounts": ledger_data}}
        with open(daemon_config_file, 'w') as f:
            json.dump(daemon_config, f, separators=(',', ':'))
    else:
        shutil.copy(custom_conf, daemon_config_file)
    
    ##############################################################
    # Launch two Mina nodes and send transactions on an interval
    ##############################################################
    
    # Common arguments for both nodes
    common_args = [
        '--file-log-level', 'Info',
        '--log-level', 'Error',
        '--seed',
        '--config-file', f'{os.getcwd()}/{conf_dir}/base.json',
        '--config-file', f'{os.getcwd()}/{daemon_config_file}'
    ]
    
    # Node-specific arguments
    node_args_1 = ['--libp2p-keypair', f'{os.getcwd()}/{libp2p_1}']
    node_args_2 = ['--libp2p-keypair', f'{os.getcwd()}/{libp2p_2}']
    
    # Handle genesis ledger directory
    if genesis_ledger_dir:
        # Clean and copy genesis directories
        for i in [1, 2]:
            genesis_dir = Path(f'localnet/genesis_{i}')
            if genesis_dir.exists():
                shutil.rmtree(genesis_dir)
            shutil.copytree(genesis_ledger_dir, genesis_dir)
        
        node_args_1.extend(['--genesis-ledger-dir', f'{os.getcwd()}/localnet/genesis_1'])
        node_args_2.extend(['--genesis-ledger-dir', f'{os.getcwd()}/localnet/genesis_2'])
    
    # Clean runtime directories
    for i in [1, 2]:
        runtime_dir = Path(f'localnet/runtime_{i}')
        if runtime_dir.exists():
            shutil.rmtree(runtime_dir)
    
    # Read peer IDs
    libp2p_1_peerid = (Path(f'{libp2p_1}.peerid')).read_text().strip()
    libp2p_2_peerid = (Path(f'{libp2p_2}.peerid')).read_text().strip()
    
    # Start block producer
    bp_cmd = [mina_exe, 'daemon'] + common_args + [
        '--peer', f'/ip4/127.0.0.1/tcp/10312/p2p/{libp2p_2_peerid}'
    ] + node_args_1 + [
        '--block-producer-key', f'{os.getcwd()}/{bp_key}',
        '--config-directory', f'{os.getcwd()}/localnet/runtime_1',
        '--client-port', '10301',
        '--external-port', '10302',
        '--rest-port', '10303'
    ]
    
    print("Block producer command:", ' '.join(f'"{arg}"' if ' ' in arg else arg for arg in bp_cmd))
    bp_process = subprocess.Popen(bp_cmd)
    print(f"Block producer PID: {bp_process.pid}")
    
    # Start snark worker
    bp_pub_content = (conf_dir / 'bp.pub').read_text().strip()
    sw_cmd = [mina_exe, 'daemon'] + common_args + [
        '--peer', f'/ip4/127.0.0.1/tcp/10302/p2p/{libp2p_1_peerid}'
    ] + node_args_2 + [
        '--run-snark-worker', bp_pub_content,
        '--work-selection', 'seq',
        '--config-directory', f'{os.getcwd()}/localnet/runtime_2',
        '--client-port', '10311',
        '--external-port', '10312',
        '--rest-port', '10313'
    ]
    
    print("Snark worker command:", ' '.join(f'"{arg}"' if ' ' in arg else arg for arg in sw_cmd))
    sw_process = subprocess.Popen(sw_cmd)
    print(f"Snark worker PID: {sw_process.pid}")
    
    setup_signal_handlers()
    
    try:
        # Wait for accounts import
        while True:
            try:
                import_cmd = f'"{mina_exe}" accounts import --privkey-path "{os.getcwd()}/{bp_key}" --rest-server 10313'
                result = subprocess.run(import_cmd, shell=True, capture_output=True, stderr=subprocess.DEVNULL)
                if result.returncode == 0:
                    break
            except:
                pass
            time.sleep(60)  # Sleep 1 minute
        
        # Export staged ledger
        while True:
            try:
                export_cmd = f'"{mina_exe}" ledger export staged-ledger --daemon-port 10311'
                result = subprocess.run(export_cmd, shell=True, capture_output=True, text=True)
                if result.returncode == 0:
                    with open('localnet/exported_staged_ledger.json', 'w') as f:
                        f.write(result.stdout)
                    break
            except:
                pass
            time.sleep(60)  # Sleep 1 minute
        
        # Send transactions
        i = 0
        while sw_process.poll() is None:  # While snark worker is running
            # Read accounts and shuffle them
            try:
                with open('localnet/exported_staged_ledger.json', 'r') as f:
                    ledger_data = json.load(f)
                
                accounts = [acc['pk'] for acc in ledger_data]
                random.shuffle(accounts)
                
                for acc in accounts:
                    if sw_process.poll() is not None:  # Check if snark worker stopped
                        break
                    
                    # Send payment
                    send_cmd = f'"{mina_exe}" client send-payment --sender "{bp_pub_content}" --receiver "{acc}" --amount 0.1 --memo "payment_{i}" --rest-server 10313'
                    result = subprocess.run(send_cmd, shell=True, capture_output=True, stderr=subprocess.DEVNULL)
                    
                    if result.returncode == 0:
                        i += 1
                        print(f"Sent tx #{i}")
                    else:
                        print(f"Failed to send tx #{i}")
                    
                    # Parse sleep interval
                    if tx_interval.endswith('s'):
                        sleep_time = int(tx_interval[:-1])
                    elif tx_interval.endswith('m'):
                        sleep_time = int(tx_interval[:-1]) * 60
                    else:
                        sleep_time = int(tx_interval)
                    
                    time.sleep(sleep_time)
            except Exception as e:
                print(f"Error in transaction loop: {e}")
                time.sleep(60)
        
        # Return the process handles for external management
        return bp_process, sw_process
        
    except KeyboardInterrupt:
        print("\nReceived interrupt, stopping processes...")
        bp_process.terminate()
        sw_process.terminate()
        bp_process.wait()
        sw_process.wait()
        raise


def main():
    """Main entry point for command line usage."""
    # Parse arguments
    parser = argparse.ArgumentParser(
        description="Creates a quick-epoch-turnaround configuration in localnet/ and launches two Mina nodes"
    )
    
    # Default values
    tx_interval = os.environ.get('TX_INTERVAL', '30s')
    delay_min = int(os.environ.get('DELAY_MIN', '20'))
    slot = int(os.environ.get('SLOT', '30'))
    mina_exe = os.environ.get('MINA_EXE', 'mina')
    
    parser.add_argument('-m', '--mina', default=mina_exe, help=f'Mina executable (default: {mina_exe})')
    parser.add_argument('-i', '--tx-interval', default=tx_interval, help=f'Interval at which to send transactions (default: {tx_interval})')
    parser.add_argument('-d', '--delay-min', type=int, default=delay_min, help=f'Delay between now and genesis timestamp, in minutes (default: {delay_min})')
    parser.add_argument('-s', '--slot', type=int, default=slot, help=f'Slot duration (block window duration), seconds (default: {slot})')
    parser.add_argument('--develop', action='store_true', help='Use develop ledger')
    parser.add_argument('-c', '--config', help='Specify a specific configuration file')
    parser.add_argument('--slot-tx-end', help='Specify slot_tx_end parameter in the config')
    parser.add_argument('--slot-chain-end', help='Specify slot_chain_end parameter in the config')
    parser.add_argument('--genesis-ledger-dir', help='Genesis ledger directory')
    parser.add_argument('keys', nargs='*', help='Additional keys')
    
    args = parser.parse_args()
    
    print(f"Creates a quick-epoch-turnaround configuration in localnet/ and launches two Mina nodes", file=sys.stderr)
    print(f"Usage: {sys.argv[0]} [-m|--mina {args.mina}] [-i|--tx-interval {args.tx_interval}] [-d|--delay-min {args.delay_min}] [-s|--slot {args.slot}] [--develop] [-c|--config ./config.json] [--slot-tx-end 100] [--slot-chain-end 130] [--genesis-ledger-dir ./genesis]", file=sys.stderr)
    print("Consider reading script's code for information on optional arguments", file=sys.stderr)
    
    setup_signal_handlers()
    
    try:
        bp_process, sw_process = run_localnet(
            mina_exe=args.mina,
            tx_interval=args.tx_interval,
            delay_min=args.delay_min,
            slot=args.slot,
            develop=args.develop,
            custom_conf=args.config,
            slot_tx_end=args.slot_tx_end,
            slot_chain_end=args.slot_chain_end,
            genesis_ledger_dir=args.genesis_ledger_dir,
            keys=args.keys
        )
        
        # Wait for processes to finish
        bp_process.wait()
        sw_process.wait()
        
    except KeyboardInterrupt:
        print("\nReceived interrupt from main")
        sys.exit(1)


if __name__ == "__main__":
    main()