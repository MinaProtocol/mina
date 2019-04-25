open Core_kernel
open Protocols
open Coda_pow
open Module_version

module Make (Inputs : sig
  module Ledger_hash : Ledger_hash_intf

  module Ledger_proof : sig
    type t [@@deriving sexp, bin_io]
  end

  module Compressed_public_key : Compressed_public_key_intf

  module Staged_ledger_aux_hash : Staged_ledger_aux_hash_intf

  module Fee_transfer :
    Fee_transfer_intf with type public_key := Compressed_public_key.t

  module Pending_coinbase : sig
    type t [@@deriving sexp, bin_io]
  end

  module Pending_coinbase_hash : Pending_coinbase_hash_intf

  module Staged_ledger_hash :
    Staged_ledger_hash_intf
    with type staged_ledger_aux_hash := Staged_ledger_aux_hash.t
     and type ledger_hash := Ledger_hash.t
     and type pending_coinbase := Pending_coinbase.t
     and type pending_coinbase_hash := Pending_coinbase_hash.t

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
   and type completed_work_checked := Inputs.Transaction_snark_work.Checked.t
   and type fee_transfer_single := Inputs.Fee_transfer.Single.t = struct
  open Inputs

  module At_most_two = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type 'a t =
            | Zero
            | One of 'a option
            | Two of ('a * 'a option) option
          [@@deriving sexp, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type 'a t = 'a Stable.Latest.t =
      | Zero
      | One of 'a option
      | Two of ('a * 'a option) option
    [@@deriving sexp]

    let increase t ws =
      match (t, ws) with
      | Zero, [] ->
          Ok (One None)
      | Zero, [a] ->
          Ok (One (Some a))
      | One _, [] ->
          Ok (Two None)
      | One _, [a] ->
          Ok (Two (Some (a, None)))
      | One _, [a; a'] ->
          Ok (Two (Some (a', Some a)))
      | _ ->
          Or_error.error_string "Error incrementing coinbase parts"
  end

  module At_most_one = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type 'a t = Zero | One of 'a option
          [@@deriving sexp, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type 'a t = 'a Stable.Latest.t = Zero | One of 'a option
    [@@deriving sexp]

    let increase t ws =
      match (t, ws) with
      | Zero, [] ->
          Ok (One None)
      | Zero, [a] ->
          Ok (One (Some a))
      | _ ->
          Or_error.error_string "Error incrementing coinbase parts"
  end

  module Ft = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = Inputs.Fee_transfer.Single.Stable.V1.t
          [@@deriving sexp, bin_io, version {unnumbered}]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t [@@deriving sexp]
  end

  module Pre_diff_with_at_most_two_coinbase = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            { completed_works: Transaction_snark_work.Stable.V1.t list
            ; user_commands: User_command.Stable.V1.t list
            ; coinbase: Ft.Stable.V1.t At_most_two.Stable.V1.t }
          [@@deriving sexp, bin_io, version {unnumbered}]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t =
      { completed_works: Transaction_snark_work.Stable.V1.t list
      ; user_commands: User_command.Stable.V1.t list
      ; coinbase: Ft.Stable.V1.t At_most_two.Stable.V1.t }
    [@@deriving sexp]
  end

  module Pre_diff_with_at_most_one_coinbase = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            { completed_works: Transaction_snark_work.Stable.V1.t list
            ; user_commands: User_command.Stable.V1.t list
            ; coinbase: Ft.Stable.V1.t At_most_one.Stable.V1.t }
          [@@deriving sexp, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t =
      { completed_works: Transaction_snark_work.Stable.V1.t list
      ; user_commands: User_command.Stable.V1.t list
      ; coinbase: Ft.Stable.V1.t At_most_one.Stable.V1.t }
    [@@deriving sexp]
  end

  module Diff = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            Pre_diff_with_at_most_two_coinbase.Stable.V1.t
            * Pre_diff_with_at_most_one_coinbase.Stable.V1.t option
          [@@deriving sexp, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t [@@deriving sexp]
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { diff: Diff.Stable.V1.t
          ; prev_hash: Staged_ledger_hash.Stable.V1.t
          ; creator: Compressed_public_key.Stable.V1.t }
        [@@deriving sexp, bin_io, version]
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
    { diff: Diff.Stable.V1.t
    ; prev_hash: Staged_ledger_hash.Stable.V1.t
    ; creator: Compressed_public_key.Stable.V1.t }
  [@@deriving sexp]

  module With_valid_signatures_and_proofs = struct
    type pre_diff_with_at_most_two_coinbase =
      { completed_works: Transaction_snark_work.Checked.t list
      ; user_commands: User_command.With_valid_signature.t list
      ; coinbase: Ft.t At_most_two.t }
    [@@deriving sexp]

    type pre_diff_with_at_most_one_coinbase =
      { completed_works: Transaction_snark_work.Checked.t list
      ; user_commands: User_command.With_valid_signature.t list
      ; coinbase: Ft.t At_most_one.t }
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
      Pre_diff_with_at_most_two_coinbase.t =
    { completed_works= forget_cw pre_diff.completed_works
    ; user_commands= (pre_diff.user_commands :> User_command.t list)
    ; coinbase= pre_diff.coinbase }

  let forget_pre_diff_with_at_most_one
      (pre_diff :
        With_valid_signatures_and_proofs.pre_diff_with_at_most_one_coinbase) =
    { Pre_diff_with_at_most_one_coinbase.completed_works=
        forget_cw pre_diff.completed_works
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

  let completed_works (t : t) =
    (fst t.diff).completed_works
    @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d -> d.completed_works)

  let coinbase (t : t) =
    let first_pre_diff, second_pre_diff_opt = t.diff in
    match
      ( first_pre_diff.coinbase
      , Option.value_map second_pre_diff_opt ~default:At_most_one.Zero
          ~f:(fun d -> d.coinbase) )
    with
    | At_most_two.Zero, At_most_one.Zero ->
        Currency.Amount.zero
    | _ ->
        Coda_praos.coinbase_amount
end
