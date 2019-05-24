open Core
open Coda_base
open Signature_lib
open Protocols.Coda_pow

module type Transaction_snark_work = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving bin_io, sexp, version]
    end
  end

  type t = Stable.V1.t

  module Checked : sig
    type t [@@deriving sexp]
  end

  val forget : Checked.t -> t
end

module Make_Staged_ledger_diff
    (Transaction_snark_work : Transaction_snark_work) =
struct
  module type S =
    Staged_ledger_diff_intf
    with type user_command := User_command.t
     and type user_command_with_valid_signature :=
                User_command.With_valid_signature.t
     and type staged_ledger_hash := Staged_ledger_hash.t
     and type public_key := Public_key.Compressed.t
     and type completed_work := Transaction_snark_work.t
     and type completed_work_checked := Transaction_snark_work.Checked.t
     and type fee_transfer_single := Fee_transfer.Single.t
end
