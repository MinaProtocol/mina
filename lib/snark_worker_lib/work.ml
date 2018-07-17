open Core_kernel
open Blockchain_snark

module Spec = struct
  type t =
    | Transition of
        Transaction_snark.Input.t * Transaction_snark.Transition.t * Ledger.t
    | Merge of Transaction_snark.t * Transaction_snark.t
  [@@deriving bin_io]
end

module Result = Transaction_snark
