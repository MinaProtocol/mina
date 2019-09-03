open Core_kernel
open Coda_base

module Make (Inputs : Inputs.S) = struct
  include Ledger.Db

  let merkle_root t =
    Frozen_ledger_hash.of_ledger_hash (merkle_root t)

  let reset_to_genesis _ = failwith "TODO"

  let to_ledger_db = Fn.id
end
