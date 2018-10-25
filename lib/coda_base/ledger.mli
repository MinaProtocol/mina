include Coda_spec.Ledger_intf.S
        with module Account = Account
         and module Hash = Merkle_hash
         and module Root_hash = Ledger_hash
         and module Keypair = Signature_lib.Keypair
         and module Payment = Payment
         and module Transaction = Transaction
