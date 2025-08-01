#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys
import tempfile
import random
from pathlib import Path


def run_command(cmd, check=True, capture_output=False, cwd=None):
    """Run a shell command."""
    print(f"+ {cmd}")
    if capture_output:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
    else:
        result = subprocess.run(cmd, shell=True, cwd=cwd)
    
    if check and result.returncode != 0:
        print(f"Command failed with exit code {result.returncode}: {cmd}")
        sys.exit(result.returncode)
    
    return result.stdout.strip() if capture_output and result.stdout else ""


def build_and_test(branch=None):
    """
    Build compatible and current branch with nix and run hardfork test.
    
    Args:
        branch: Branch name for CI execution. If None, runs locally.
    
    Returns:
        True if test passes, False otherwise
    """
    # Enable exit on error and command echoing equivalent
    # This is handled by our run_command function
    
    # NIX options
    nix_opts = ['--accept-flake-config', '--experimental-features', '"nix-command flakes"']
    
    # Handle NIX cache secret
    nix_secret_key = None
    if os.environ.get('NIX_CACHE_NAR_SECRET'):
        with open('/tmp/nix-cache-secret', 'w') as f:
            f.write(os.environ['NIX_CACHE_NAR_SECRET'])
        print("Configuring the NAR signing secret")
        nix_secret_key = '/tmp/nix-cache-secret'
    
    # Handle GCP uploading configuration
    nix_post_build_hook = None
    if os.environ.get('NIX_CACHE_GCP_ID') and os.environ.get('NIX_CACHE_GCP_SECRET'):
        print("GCP uploading configured (for nix binaries)")
        
        post_build_script = '''#!/bin/sh

set -eu
set -f # disable globbing
export IFS=' '

echo $OUT_PATHS | tr ' ' '\\n' >> /tmp/nix-paths
'''
        with open('/tmp/nix-post-build', 'w') as f:
            f.write(post_build_script)
        os.chmod('/tmp/nix-post-build', 0o755)
        nix_post_build_hook = '/tmp/nix-post-build'
    
    # Add additional NIX options
    if nix_post_build_hook:
        nix_opts.extend(['--post-build-hook', nix_post_build_hook])
    if nix_secret_key:
        nix_opts.extend(['--secret-key-files', nix_secret_key])
    
    # Get initial directory and script directory
    init_dir = os.getcwd()
    script_dir = Path(__file__).parent.absolute()
    
    # Handle CI vs local execution
    if branch is not None:
        # Branch is specified, this is a CI run
        
        # Set up CI environment
        if os.path.exists('/etc/localtime'):
            os.unlink('/etc/localtime')
        os.symlink('/usr/share/zoneinfo/UTC', '/etc/localtime')
        
        # Change ownership (equivalent to chown -R "${USER}" /workdir)
        user = os.environ.get('USER', 'root')
        run_command(f'chown -R "{user}" /workdir')
        
        # Git configuration
        run_command('git config --global --add safe.directory /workdir')
        run_command('git fetch')
        
        # Install required packages
        run_command('nix-env -iA unstable.jq')
        run_command('nix-env -iA unstable.curl')
        run_command('nix-env -iA unstable.gnused')
        run_command('nix-env -iA unstable.git-lfs')
    
    # Build compatible version if symlink doesn't exist
    compatible_devnet_link = Path('compatible-devnet')
    if not compatible_devnet_link.is_symlink():
        if branch is None:
            # Local execution - clone in temporary directory
            compatible_build = tempfile.mkdtemp()
            run_command(f'git clone -b compatible --single-branch "https://github.com/MinaProtocol/mina.git" "{compatible_build}"')
            os.chdir(compatible_build)
        else:
            # CI execution - use current directory
            run_command(f'git checkout -f {branch}')
            run_command('git checkout -f compatible')
            run_command(f'git checkout -f {branch} -- scripts/hardfork')
            compatible_build = init_dir
        
        # Update submodules and build
        run_command('git submodule sync --recursive')
        run_command('git submodule update --init --recursive')
        
        nix_cmd_1 = f'nix {" ".join(nix_opts)} build "{compatible_build}?submodules=1#devnet" --out-link "{init_dir}/compatible-devnet"'
        nix_cmd_2 = f'nix {" ".join(nix_opts)} build "{compatible_build}?submodules=1#devnet.genesis" --out-link "{init_dir}/compatible-devnet"'
        
        run_command(nix_cmd_1)
        run_command(nix_cmd_2)
        
        if branch is None:
            # Clean up temporary directory for local execution
            os.chdir(init_dir)
            shutil.rmtree(compatible_build)
    
    # Handle fork branch building
    if branch is not None:
        # CI execution - checkout fork branch
        run_command(f'git checkout -f {branch}')
        run_command('git submodule sync --recursive')
        run_command('git submodule update --init --recursive')
    
    # Build fork version
    nix_cmd_3 = f'nix {" ".join(nix_opts)} build "{init_dir}?submodules=1#devnet" --out-link "{init_dir}/fork-devnet"'
    nix_cmd_4 = f'nix {" ".join(nix_opts)} build "{init_dir}?submodules=1#devnet.genesis" --out-link "{init_dir}/fork-devnet"'
    
    run_command(nix_cmd_3)
    run_command(nix_cmd_4)
    
    # Handle GCP cache upload
    if os.environ.get('NIX_CACHE_GCP_ID') and os.environ.get('NIX_CACHE_GCP_SECRET'):
        # Create AWS credentials for GCP
        aws_dir = Path.home() / '.aws'
        aws_dir.mkdir(exist_ok=True)
        
        credentials_content = f"""[default]
aws_access_key_id={os.environ['NIX_CACHE_GCP_ID']}
aws_secret_access_key={os.environ['NIX_CACHE_GCP_SECRET']}
"""
        with open(aws_dir / 'credentials', 'w') as f:
            f.write(credentials_content)
        
        # Upload to nix cache
        run_command('nix --experimental-features nix-command copy --to "s3://mina-nix-cache?endpoint=https://storage.googleapis.com" --stdin < /tmp/nix-paths')
    
    # Set SLOT_TX_END with random value if not set
    slot_tx_end = os.environ.get('SLOT_TX_END')
    if not slot_tx_end:
        slot_tx_end = str(random.randint(30, 149))  # Random between 30 and 149 (30 + random % 120)
        os.environ['SLOT_TX_END'] = slot_tx_end
    
    print(f"Running HF test with SLOT_TX_END={slot_tx_end}")
    
    # Import and run the test function
    from test import run_hardfork_test
    
    try:
        success = run_hardfork_test(
            main_mina_exe="compatible-devnet/bin/mina",
            main_runtime_genesis_ledger_exe="compatible-devnet-genesis/bin/runtime_genesis_ledger",
            fork_mina_exe="fork-devnet/bin/mina",
            fork_runtime_genesis_ledger_exe="fork-devnet-genesis/bin/runtime_genesis_ledger"
        )
        
        if success:
            print("HF test completed successfully")
            return True
        else:
            print("HF test failed")
            return False
    except Exception as e:
        print(f"HF test failed with error: {e}")
        return False


def main():
    """Main entry point for command line usage."""
    branch = sys.argv[1] if len(sys.argv) > 1 else None
    
    success = build_and_test(branch)
    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()