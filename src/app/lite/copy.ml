let proof_tooltip =
  [ `Text "The Coda network compresses its entire blockchain into a 1 kilobyte "
  ; `Link
      ( "zk-SNARK"
      , "https://en.wikipedia.org/wiki/Non-interactive_zero-knowledge_proof" )
  ; `Text
      " proof, which serves as a cryptographic certificate of the protocol \
       state's integrity.\n\
       This certificate, called a \"succinct blockchain\", takes the place of \
       the GBs long, ever-growing blockchains used for validation in other \
       cryptocurrencies."
  ; `New_line
  ; `Text
      "The Coda testnet is sending a copy of this zk-SNARK live to a client \
       in your browser, which uses the SNARK to verify the protocol state." ]

let proof_tooltip_alt =
  [ `Text
      "The Coda network incrementally updates a 1 kilobyte zk-SNARK proof, \
       which serves as a cryptographic certificate of the protocol state's \
       integrity. Because SNARKs are so small and cheap to verify, the Coda \
       testnet can send a copy of this snark live to a client on your device."
  ]

let state_tooltip =
  [ `Text
      "The zk-SNARK proof serves as a succinct blockchain,\n\
       validating the entire protocol state just as a heavy blockchain does \
       in existing cryptocurrencies."
  ; `New_line
  ; `Text "The staged and locked ledger hashes are the "
  ; `Link ("merkle roots", "https://en.wikipedia.org/wiki/Merkle_tree")
  ; `Text
      " of two versions of the database of accounts.\n\
       Changes to accounts are reflected immediately in the staged ledger hash.\n\
       The locked ledger hash is set from the staged ledger hash periodically,\n\
       as zk-SNARK proofs are computed." ]

let account_tooltip =
  [ `Text
      "Once a client has a protocol state and a succinct blockchain \
       certifying that state, they can get their account information with a \
       small amount of additional data.\n\
       Namely, they need a merkle-path from the protocol state's ledger hash \
       to their account."
  ; `New_line
  ; `Text
      "The succinct blockchain, protocol state, merkle-path, and account \
       information are altogether just a few kilobytes,\n\
       so Coda can provide a full proof of the state of an account with just \
       this tiny amount of data." ]
