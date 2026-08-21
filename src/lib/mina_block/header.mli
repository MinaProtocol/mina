(** {1 Mina Block Header}

    The block header is the metadata component of a Mina block that contains
    the protocol state and information and a cryptographic proof for the state
    validity.

    {2 What's in a Header?}

    The header is essentially the "control information" for a block:
    - {b Protocol State}: The current state of the blockchain (account balances,
      validator set, etc.)
    - {b Protocol State Proof}: A zkSNARK that proves the protocol state is valid
    - {b Delta Block Chain Proof}: Links this block to the previous block in the chain
    - {b Protocol Versions}: Current and potentially proposed protocol versions

    {2 zkSNARK Proofs in Headers}

    The most important part of a Mina block header is the protocol state proof.
    This zkSNARK proof validates:
    - All transactions in the current block are valid
    - The previous block's state was valid
    - The transition from the previous state to the current state is correct

    Because these proofs are recursive, a single header proof validates the
    entire blockchain history, not just the current block.

    {2 For Newcomers}

    Think of the header as a "certificate of validity" for the block. While
    the block body contains the actual transaction data, the header contains
    the cryptographic proof that:
    1. The transactions were processed correctly
    2. The resulting state is valid
    3. The entire blockchain history is valid

    This is what allows Mina to be "succinct" - you only need to check the
    header's proof to verify the entire blockchain.
*)
include
  Header_intf.Full
    with type Stable.V2.t = Mina_wire_types.Mina_block.Header.V2.t
