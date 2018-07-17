open Core_kernel
open Blockchain_snark

module Spec : sig
  type t =
    | Transition of
        Transaction_snark.Statement.t
        * Transaction_snark.Transition.t
        * Ledger.t
    | Merge of Transaction_snark.t * Transaction_snark.t
  [@@deriving bin_io]
end

module Result : sig
  type t = Transaction_snark.t [@@deriving bin_io]
end
