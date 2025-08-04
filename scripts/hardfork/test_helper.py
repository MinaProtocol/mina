#!/usr/bin/env python3

import json
import requests
import subprocess
import sys
from typing import Dict, List, Optional, Tuple


def graphql(port: int, query: str) -> Dict:
    """Execute a GraphQL query against the Mina daemon."""
    url = f"http://localhost:{port}/graphql"
    headers = {"Content-Type": "application/json"}
    data = {"query": f"query Q {{{query}}}"}
    
    response = requests.post(url, headers=headers, json=data)
    return response.json()


def get_height_and_slot_of_earliest(port: int) -> str:
    """Get height and slot of the earliest block."""
    query = 'bestChain { protocolState { consensusState { blockHeight slotSinceGenesis } } }'
    result = graphql(port, query)
    
    consensus_state = result['data']['bestChain'][0]['protocolState']['consensusState']
    block_height = consensus_state['blockHeight']
    slot_since_genesis = consensus_state['slotSinceGenesis']
    
    return f"{block_height},{slot_since_genesis}"


def get_height(port: int) -> int:
    """Get the block height of the latest block."""
    query = 'bestChain(maxLength: 1) { protocolState { consensusState { blockHeight } } }'
    result = graphql(port, query)
    
    return int(result['data']['bestChain'][-1]['protocolState']['consensusState']['blockHeight'])


def get_fork_config(port: int) -> Dict:
    """Get fork configuration from the daemon."""
    query = 'fork_config'
    result = graphql(port, query)
    
    return result['data']['fork_config']


def blocks_with_user_commands(port: int) -> int:
    """Count blocks with user commands."""
    query = 'bestChain { commandTransactionCount }'
    result = graphql(port, query)
    
    blocks_with_commands = [
        block for block in result['data']['bestChain'] 
        if block['commandTransactionCount'] > 0
    ]
    
    return len(blocks_with_commands)


# Block query constants
BLOCKS_QUERY = """
bestChain {
  commandTransactionCount
  protocolState {
    consensusState {
      blockHeight
      slotSinceGenesis
      epoch
      stakingEpochData {
        ledger { hash }
        seed
      }
      nextEpochData {
        ledger { hash }
        seed
      }
    }
    blockchainState {
      stagedLedgerHash
      snarkedLedgerHash
    }
  }
  transactions {
    coinbase
    feeTransfer { fee }
  }
  stateHash
}
"""

# Block field indices
IX_STATE_HASH = 0
IX_HEIGHT = 1
IX_SLOT = 2
IX_NON_EMPTY = 3
IX_CUR_EPOCH_HASH = 4
IX_CUR_EPOCH_SEED = 5
IX_NEXT_EPOCH_HASH = 6
IX_NEXT_EPOCH_SEED = 7
IX_STAGED_HASH = 8
IX_SNARKED_HASH = 9
IX_EPOCH = 10


def blocks(port: int) -> List[str]:
    """Get blocks data and format it as comma-separated values."""
    result = graphql(port, BLOCKS_QUERY)
    
    formatted_blocks = []
    for block in result['data']['bestChain']:
        consensus_state = block['protocolState']['consensusState']
        blockchain_state = block['protocolState']['blockchainState']
        
        # Calculate if block is non-empty
        fee_transfer_count = len(block['transactions']['feeTransfer'])
        coinbase_count = 1 if block['transactions']['coinbase'] != "0" else 0
        non_empty = (block['commandTransactionCount'] + fee_transfer_count + coinbase_count) > 0
        
        fields = [
            block['stateHash'],
            str(consensus_state['blockHeight']),
            str(consensus_state['slotSinceGenesis']),
            str(non_empty).lower(),
            consensus_state['stakingEpochData']['ledger']['hash'],
            consensus_state['stakingEpochData']['seed'],
            consensus_state['nextEpochData']['ledger']['hash'],
            consensus_state['nextEpochData']['seed'],
            blockchain_state['stagedLedgerHash'],
            blockchain_state['snarkedLedgerHash'],
            str(consensus_state['epoch'])
        ]
        
        formatted_blocks.append(','.join(fields))
    
    return formatted_blocks


def latest_nonempty_block(block_lines: List[str]) -> str:
    """
    Process stream of blocks and calculate:
    1. maximum seen slot
    2. Latest snarked ledger hashes per-epoch
    3. Latest non-empty block
    """
    # data of a non-empty block with the largest slot
    latest = {}
    latest[IX_SLOT] = 0
    
    # Latest snarked hashes per epoch
    snarked_hash_pe = {}
    # Latest seen slot per epoch
    slot_pe = {}
    
    max_slot = 0
    
    # Process each block line
    for line in block_lines:
        fields = line.split(',')
        
        slot = int(fields[IX_SLOT])
        if max_slot < slot:
            max_slot = slot
            
        non_empty = fields[IX_NON_EMPTY] == 'true'
        if non_empty and latest.get(IX_SLOT, 0) < slot:
            latest = {i: fields[i] for i in range(len(fields))}
            latest[IX_SLOT] = slot
            
        epoch = int(fields[IX_EPOCH])
        if epoch not in slot_pe or slot_pe[epoch] < slot:
            slot_pe[epoch] = slot
            snarked_hash_pe[epoch] = fields[IX_SNARKED_HASH]
    
    # Format output
    epoch_str = ':'.join(str(e) for e in sorted(slot_pe.keys()))
    snarked_hash_pe_str = ':'.join(snarked_hash_pe[e] for e in sorted(slot_pe.keys()))
    latest_str = ','.join(str(latest.get(i, '')) for i in range(11))  # 11 fields total
    
    return f"{max_slot},{epoch_str},{snarked_hash_pe_str},{latest_str}"


# Export indices as environment variables for compatibility when imported
import os
os.environ['IX_STATE_HASH'] = str(IX_STATE_HASH)
os.environ['IX_HEIGHT'] = str(IX_HEIGHT)
os.environ['IX_SLOT'] = str(IX_SLOT)
os.environ['IX_NON_EMPTY'] = str(IX_NON_EMPTY)
os.environ['IX_CUR_EPOCH_HASH'] = str(IX_CUR_EPOCH_HASH)
os.environ['IX_CUR_EPOCH_SEED'] = str(IX_CUR_EPOCH_SEED)
os.environ['IX_NEXT_EPOCH_HASH'] = str(IX_NEXT_EPOCH_HASH)
os.environ['IX_NEXT_EPOCH_SEED'] = str(IX_NEXT_EPOCH_SEED)
os.environ['IX_STAGED_HASH'] = str(IX_STAGED_HASH)
os.environ['IX_SNARKED_HASH'] = str(IX_SNARKED_HASH)
os.environ['IX_EPOCH'] = str(IX_EPOCH)