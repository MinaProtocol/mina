open Core_kernel
open Protocols
open Coda_pow

module Make (Inputs : sig
  module Ledger_hash : Ledger_hash_intf

  module Ledger_proof : sig
    type t [@@deriving sexp, bin_io]
  end

  module Staged_ledger_aux_hash : Staged_ledger_aux_hash_intf

  module Pending_coinbase_hash : Pending_coinbase_hash_intf

  module Staged_ledger_hash :
    Staged_ledger_hash_intf
    with type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
     and type ledger_hash := Ledger_hash.t
     and type pending_coinbase_hash := Pending_coinbase_hash.t

  module Compressed_public_key : Compressed_public_key_intf

  module User_command :
    User_command_intf with type public_key := Compressed_public_key.t

  module Transaction_snark_work :
    Transaction_snark_work_intf
    with type public_key := Compressed_public_key.t
     and type statement := Transaction_snark.Statement.t
     and type proof := Ledger_proof.t

  module Fee_transfer :
    Fee_transfer_intf with type public_key := Compressed_public_key.t
end) :
  Coda_pow.Staged_ledger_diff_intf
  with type user_command := Inputs.User_command.t
   and type user_command_with_valid_signature :=
              Inputs.User_command.With_valid_signature.t
   and type staged_ledger_hash := Inputs.Staged_ledger_hash.t
   and type public_key := Inputs.Compressed_public_key.t
   and type completed_work := Inputs.Transaction_snark_work.t
   and type completed_work_checked := Inputs.Transaction_snark_work.Checked.t
   and type fee_transfer_single := Inputs.Fee_transfer.single = struct
  open Inputs

  module At_most_two = struct
    type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
    [@@deriving sexp, bin_io]

    let increase t ws =
      match (t, ws) with
      | Zero, [] -> Ok (One None)
      | Zero, [a] -> Ok (One (Some a))
      | One _, [] -> Ok (Two None)
      | One _, [a] -> Ok (Two (Some (a, None)))
      | One _, [a; a'] -> Ok (Two (Some (a', Some a)))
      | _ -> Or_error.error_string "Error incrementing coinbase parts"
  end

  module At_most_one = struct
    type 'a t = Zero | One of 'a option [@@deriving sexp, bin_io]

    let increase t ws =
      match (t, ws) with
      | Zero, [] -> Ok (One None)
      | Zero, [a] -> Ok (One (Some a))
      | _ -> Or_error.error_string "Error incrementing coinbase parts"
  end

  type ft = Inputs.Fee_transfer.single [@@deriving sexp, bin_io]

  type pre_diff_with_at_most_two_coinbase =
    { completed_works: Transaction_snark_work.t list
    ; user_commands: User_command.t list
    ; coinbase: ft At_most_two.t }
  [@@deriving sexp, bin_io]

  type pre_diff_with_at_most_one_coinbase =
    { completed_works: Transaction_snark_work.t list
    ; user_commands: User_command.t list
    ; coinbase: ft At_most_one.t }
  [@@deriving sexp, bin_io]

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option
  [@@deriving sexp, bin_io]

  type t =
    { diff: diff
    ; prev_hash: Staged_ledger_hash.t
    ; creator: Compressed_public_key.t }
  [@@deriving sexp, bin_io]

  module With_valid_signatures_and_proofs = struct
    type pre_diff_with_at_most_two_coinbase =
      { completed_works: Transaction_snark_work.Checked.t list
      ; user_commands: User_command.With_valid_signature.t list
      ; coinbase: ft At_most_two.t }
    [@@deriving sexp]

    type pre_diff_with_at_most_one_coinbase =
      { completed_works: Transaction_snark_work.Checked.t list
      ; user_commands: User_command.With_valid_signature.t list
      ; coinbase: ft At_most_one.t }
    [@@deriving sexp]

    type diff =
      pre_diff_with_at_most_two_coinbase
      * pre_diff_with_at_most_one_coinbase option
    [@@deriving sexp]

    type t =
      { diff: diff
      ; prev_hash: Staged_ledger_hash.t
      ; creator: Compressed_public_key.t }
    [@@deriving sexp]

    let user_commands t =
      (fst t.diff).user_commands
      @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d -> d.user_commands)
  end

  let forget_cw cw_list = List.map ~f:Transaction_snark_work.forget cw_list

  let forget_pre_diff_with_at_most_two
      (pre_diff :
        With_valid_signatures_and_proofs.pre_diff_with_at_most_two_coinbase) :
      pre_diff_with_at_most_two_coinbase =
    { completed_works= forget_cw pre_diff.completed_works
    ; user_commands= (pre_diff.user_commands :> User_command.t list)
    ; coinbase= pre_diff.coinbase }

  let forget_pre_diff_with_at_most_one
      (pre_diff :
        With_valid_signatures_and_proofs.pre_diff_with_at_most_one_coinbase) =
    { completed_works= forget_cw pre_diff.completed_works
    ; user_commands= (pre_diff.user_commands :> User_command.t list)
    ; coinbase= pre_diff.coinbase }

  let forget (t : With_valid_signatures_and_proofs.t) =
    { diff=
        ( forget_pre_diff_with_at_most_two (fst t.diff)
        , Option.map (snd t.diff) ~f:forget_pre_diff_with_at_most_one )
    ; prev_hash= t.prev_hash
    ; creator= t.creator }

  let user_commands (t : t) =
    (fst t.diff).user_commands
    @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d -> d.user_commands)
end
