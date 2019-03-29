open Core_kernel
open Module_version
open Signature_lib

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

(* TODO: version *)

type ft = Fee_transfer.Single.Stable.V1.t [@@deriving sexp, bin_io]

(* TODO: version *)

type pre_diff_with_at_most_two_coinbase =
  { completed_works: Transaction_snark_work.Stable.V1.t list
  ; user_commands: User_command.t list
  ; coinbase: ft At_most_two.t }
[@@deriving sexp, bin_io]

(* TODO: version *)

type pre_diff_with_at_most_one_coinbase =
  { completed_works: Transaction_snark_work.Stable.V1.t list
  ; user_commands: User_command.t list
  ; coinbase: ft At_most_one.t }
[@@deriving sexp, bin_io]

type diff =
  pre_diff_with_at_most_two_coinbase
  * pre_diff_with_at_most_one_coinbase option
[@@deriving sexp, bin_io]

module Stable = struct
  module V1 = struct
    module T = struct
      let version = 1

      type t =
        { diff: diff
        ; prev_hash: Staged_ledger_hash.Stable.V1.t
        ; creator: Public_key.Compressed.Stable.V1.t }
      [@@deriving sexp, bin_io]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "staged_ledger_diff"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

type t = Stable.Latest.t =
  { diff: diff
  ; prev_hash: Staged_ledger_hash.t
  ; creator: Public_key.Compressed.Stable.V1.t }
[@@deriving sexp]

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
    ; creator: Public_key.Compressed.t }
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
