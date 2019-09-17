## Summary
[summary]: #summary

This RFC proposes a new standard for names related to our implementation proof of stake.

## Motivation
[motivation]: #motivation

There has been a great deal of misunderstandings and miscommunications around proof of stake in the past, and nearly all of this has been due to non-unique and non-specific names. By fixing this, the hope would be that the team is able to communicate more effectively about concepts in proof of stake without relaying a ground base of information at the beginning of every meeting.

## Detailed design
[detailed-design]: #detailed-design

The biggest source of confusion is the ambiguous and non-unique use of "prev" and "next". The goal with these names is to remove those names and keep all names unambiguous. These name changes would be reflected in the code after we agree upon them.

```
Epoch Ledger: the ledger for VRF evaluations (associated with a specific epoch)
Current Epoch: the epoch which the blockchain is currently in
Staking Epoch: the epoch before the current epoch (which provides information for VRF evaluations within the current epoch)
Staking Epoch Ledger: the epoch ledger from the staking epoch (actively used for VRF evaluations within the current epoch)
Next Epoch Ledger: the epoch ledger from the current epoch (will be used for VRF evaluations in the next epoch)
Blockchain Length: the total number of blocks in the blockchain
Epoch Count: the total number of epochs that contain blocks
Epoch Length: the number of blocks in an epoch
Epoch Seed Update Range: the middle third of an epoch (where the epoch seed is calculated)
Epoch Seed: the input for the VRF message which is calculated in the seed update range
Checkpoint: a pointer to a state hash that is in the blockchain
Epoch Start Checkpoint: a pointer to the state hash immediately preceding the first block of an epoch
Epoch Lock Checkpoint: a pointer to the state hash immediately preceding the first block in the last third of an epoch (the last block in the seed update range)
```
