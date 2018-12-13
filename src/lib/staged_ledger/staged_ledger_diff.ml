open Core_kernel
open Protocols
open Coda_pow

module Make (Inputs : sig
  module Ledger_hash : Ledger_hash_intf

  module Ledger_proof : sig
    type t [@@deriving sexp, bin_io]
  end

  module Staged_ledger_aux_hash : Staged_ledger_aux_hash_intf

  module Staged_ledger_hash :
    Staged_ledger_hash_intf
    with type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
     and type ledger_hash := Ledger_hash.t

  module Compressed_public_key : Compressed_public_key_intf

  module User_command :
    User_command_intf with type public_key := Compressed_public_key.t

  module Transaction_snark_work :
    Transaction_snark_work_intf
    with type public_key := Compressed_public_key.t
     and type statement := Transaction_snark.Statement.t
     and type proof := Ledger_proof.t
end) :
  Coda_pow.Staged_ledger_diff_intf
  with type user_command := Inputs.User_command.t
   and type user_command_with_valid_signature :=
              Inputs.User_command.With_valid_signature.t
   and type staged_ledger_hash := Inputs.Staged_ledger_hash.t
   and type public_key := Inputs.Compressed_public_key.t
   and type completed_work := Inputs.Transaction_snark_work.t
   and type completed_work_checked := Inputs.Transaction_snark_work.Checked.t =
struct
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

  type diff =
    { completed_works: Transaction_snark_work.t list
    ; user_commands: User_command.t list }
  [@@deriving sexp, bin_io]

  type diff_with_at_most_two_coinbase =
    {diff: diff; coinbase_parts: Transaction_snark_work.t At_most_two.t}
  [@@deriving sexp, bin_io]

  type diff_with_at_most_one_coinbase =
    {diff: diff; coinbase_added: Transaction_snark_work.t At_most_one.t}
  [@@deriving sexp, bin_io]

  type pre_diffs =
    ( diff_with_at_most_one_coinbase
    , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
    Either.t
  [@@deriving sexp, bin_io]

  type t =
    { pre_diffs: pre_diffs
    ; prev_hash: Staged_ledger_hash.t
    ; creator: Compressed_public_key.t }
  [@@deriving sexp, bin_io]

  module Verified = struct
    type diff =
      { completed_works: Transaction_snark_work.Checked.t list
      ; user_commands: User_command.t list }
    [@@deriving sexp, bin_io]

    type diff_with_at_most_two_coinbase =
      { diff: diff
      ; coinbase_parts: Transaction_snark_work.Checked.t At_most_two.t }
    [@@deriving sexp, bin_io]

    type diff_with_at_most_one_coinbase =
      { diff: diff
      ; coinbase_added: Transaction_snark_work.Checked.t At_most_one.t }
    [@@deriving sexp, bin_io]

    type pre_diffs =
      ( diff_with_at_most_one_coinbase
      , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
      Either.t
    [@@deriving sexp, bin_io]

    type t =
      { pre_diffs: pre_diffs
      ; prev_hash: Staged_ledger_hash.t
      ; creator: Compressed_public_key.t }
    [@@deriving sexp, bin_io]
  end

  type verified = Verified.t [@@deriving sexp, bin_io]

  (* forget the verification of completed works in a verified diff
     unlike Staged_ledger.checked_diff_of_diff, there's no possibility of failure *)

  let forget_verified (verified : Verified.t) : t =
    let diff_of_work completed_works user_commands =
      {completed_works; user_commands}
    in
    let uncheck_at_most_one
        (at_most_one : Verified.diff_with_at_most_one_coinbase) =
      let checked_diff = at_most_one.diff in
      let (completed_works : Transaction_snark_work.t list) =
        List.map checked_diff.completed_works ~f:Transaction_snark_work.forget
      in
      let diff = diff_of_work completed_works checked_diff.user_commands in
      match at_most_one.coinbase_added with
      | Zero -> {diff; coinbase_added= Zero}
      | One maybe_work -> (
        match maybe_work with
        | None -> {diff; coinbase_added= One None}
        | Some work ->
            let completed_work = Transaction_snark_work.forget work in
            {diff; coinbase_added= One (Some completed_work)} )
    in
    let uncheck_at_most_two
        (at_most_two : Verified.diff_with_at_most_two_coinbase) =
      let checked_diff = at_most_two.diff in
      let completed_works =
        List.map checked_diff.completed_works ~f:Transaction_snark_work.forget
      in
      let diff = diff_of_work completed_works checked_diff.user_commands in
      match at_most_two.coinbase_parts with
      | Zero -> {diff; coinbase_parts= Zero}
      | One maybe_work -> (
        match maybe_work with
        | None -> {diff; coinbase_parts= One None}
        | Some work ->
            let completed_work = Transaction_snark_work.forget work in
            {diff; coinbase_parts= One (Some completed_work)} )
      | Two maybe_works -> (
        match maybe_works with
        | None -> {diff; coinbase_parts= Two None}
        | Some (work_1, maybe_work) -> (
            let completed_work_1 = Transaction_snark_work.forget work_1 in
            match maybe_work with
            | None ->
                {diff; coinbase_parts= Two (Some (completed_work_1, None))}
            | Some work_2 ->
                let completed_work_2 = Transaction_snark_work.forget work_2 in
                { diff
                ; coinbase_parts=
                    Two (Some (completed_work_1, Some completed_work_2)) } ) )
    in
    let pre_diffs =
      Either.map verified.pre_diffs ~first:uncheck_at_most_one
        ~second:(fun (at_most_two, at_most_one) ->
          (uncheck_at_most_two at_most_two, uncheck_at_most_one at_most_one) )
    in
    {pre_diffs; prev_hash= verified.prev_hash; creator= verified.creator}

  module With_valid_signatures_and_proofs = struct
    type diff =
      { completed_works: Transaction_snark_work.Checked.t list
      ; user_commands: User_command.With_valid_signature.t list }
    [@@deriving sexp]

    type diff_with_at_most_two_coinbase =
      { diff: diff
      ; coinbase_parts: Inputs.Transaction_snark_work.Checked.t At_most_two.t
      }
    [@@deriving sexp]

    type diff_with_at_most_one_coinbase =
      { diff: diff
      ; coinbase_added: Inputs.Transaction_snark_work.Checked.t At_most_one.t
      }
    [@@deriving sexp]

    type pre_diffs =
      ( diff_with_at_most_one_coinbase
      , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
      Either.t
    [@@deriving sexp]

    type t =
      { pre_diffs: pre_diffs
      ; prev_hash: Staged_ledger_hash.t
      ; creator: Compressed_public_key.t }
    [@@deriving sexp]

    let user_commands t =
      Either.value_map t.pre_diffs
        ~first:(fun d -> d.diff.user_commands)
        ~second:(fun d ->
          (fst d).diff.user_commands @ (snd d).diff.user_commands )
  end

  let forget_diff
      {With_valid_signatures_and_proofs.completed_works; user_commands} =
    { completed_works= List.map ~f:Transaction_snark_work.forget completed_works
    ; user_commands= (user_commands :> User_command.t list) }

  let forget_work_opt = Option.map ~f:Transaction_snark_work.forget

  let forget_pre_diff_with_at_most_two
      {With_valid_signatures_and_proofs.diff; coinbase_parts} =
    let forget_cw =
      match coinbase_parts with
      | At_most_two.Zero -> At_most_two.Zero
      | One cw -> One (forget_work_opt cw)
      | Two cw_pair ->
          Two
            (Option.map cw_pair ~f:(fun (cw, cw_opt) ->
                 (Transaction_snark_work.forget cw, forget_work_opt cw_opt) ))
    in
    {diff= forget_diff diff; coinbase_parts= forget_cw}

  let forget_pre_diff_with_at_most_one
      {With_valid_signatures_and_proofs.diff; coinbase_added} =
    let forget_cw =
      match coinbase_added with
      | At_most_one.Zero -> At_most_one.Zero
      | One cw -> One (forget_work_opt cw)
    in
    {diff= forget_diff diff; coinbase_added= forget_cw}

  let forget_validated (t : With_valid_signatures_and_proofs.t) =
    { pre_diffs=
        Either.map t.pre_diffs ~first:forget_pre_diff_with_at_most_one
          ~second:(fun d ->
            ( forget_pre_diff_with_at_most_two (fst d)
            , forget_pre_diff_with_at_most_one (snd d) ) )
    ; prev_hash= t.prev_hash
    ; creator= t.creator }

  let user_commands (t : t) =
    Either.value_map t.pre_diffs
      ~first:(fun d -> d.diff.user_commands)
      ~second:(fun d -> (fst d).diff.user_commands @ (snd d).diff.user_commands)
end
