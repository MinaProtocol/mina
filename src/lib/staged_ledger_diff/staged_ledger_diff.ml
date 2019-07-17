open Core_kernel
open Coda_base
open Signature_lib
open Module_version

module Make (Transaction_snark_work : sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving bin_io, sexp, to_yojson, version]
    end
  end

  type t = Stable.V1.t

  module Checked : sig
    type t [@@deriving sexp, to_yojson]
  end

  val forget : Checked.t -> t
end) :
  Coda_intf.Staged_ledger_diff_intf
  with type transaction_snark_work := Transaction_snark_work.t
   and type transaction_snark_work_checked := Transaction_snark_work.Checked.t =
struct
  module At_most_two = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type 'a t =
            | Zero
            | One of 'a option
            | Two of ('a * 'a option) option
          [@@deriving sexp, to_yojson, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type 'a t = 'a Stable.Latest.t =
      | Zero
      | One of 'a option
      | Two of ('a * 'a option) option
    [@@deriving sexp, to_yojson]

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
          [@@deriving sexp, to_yojson, bin_io, version]
        end

        include T
      end

      module Latest = V1
    end

    type 'a t = 'a Stable.Latest.t = Zero | One of 'a option
    [@@deriving sexp, to_yojson]

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
          type t = Fee_transfer.Single.Stable.V1.t
          [@@deriving sexp, to_yojson, bin_io, version {unnumbered}]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t [@@deriving sexp, to_yojson]
  end

  module Pre_diff_with_at_most_two_coinbase = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            { completed_works: Transaction_snark_work.Stable.V1.t list
            ; user_commands: User_command.Stable.V1.t list
            ; coinbase: Ft.Stable.V1.t At_most_two.Stable.V1.t }
          [@@deriving sexp, to_yojson, bin_io, version {unnumbered}]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t =
      { completed_works: Transaction_snark_work.Stable.V1.t list
      ; user_commands: User_command.Stable.V1.t list
      ; coinbase: Ft.Stable.V1.t At_most_two.Stable.V1.t }
    [@@deriving sexp, to_yojson]
  end

  module Pre_diff_with_at_most_one_coinbase = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            { completed_works: Transaction_snark_work.Stable.V1.t list
            ; user_commands: User_command.Stable.V1.t list
            ; coinbase: Ft.Stable.V1.t At_most_one.Stable.V1.t }
          [@@deriving sexp, to_yojson, bin_io, version {unnumbered}]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t =
      { completed_works: Transaction_snark_work.Stable.V1.t list
      ; user_commands: User_command.Stable.V1.t list
      ; coinbase: Ft.Stable.V1.t At_most_one.Stable.V1.t }
    [@@deriving sexp, to_yojson]
  end

  module Diff = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            Pre_diff_with_at_most_two_coinbase.Stable.V1.t
            * Pre_diff_with_at_most_one_coinbase.Stable.V1.t option
          [@@deriving sexp, to_yojson, bin_io, version {unnumbered}]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t [@@deriving sexp, to_yojson]
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          {diff: Diff.Stable.V1.t; creator: Public_key.Compressed.Stable.V1.t}
        [@@deriving sexp, to_yojson, bin_io, version]
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
    {diff: Diff.Stable.V1.t; creator: Public_key.Compressed.Stable.V1.t}
  [@@deriving sexp, to_yojson, fields]

  module With_valid_signatures_and_proofs = struct
    type pre_diff_with_at_most_two_coinbase =
      { completed_works: Transaction_snark_work.Checked.t list
      ; user_commands: User_command.With_valid_signature.t list
      ; coinbase: Ft.t At_most_two.t }
    [@@deriving sexp, to_yojson]

    type pre_diff_with_at_most_one_coinbase =
      { completed_works: Transaction_snark_work.Checked.t list
      ; user_commands: User_command.With_valid_signature.t list
      ; coinbase: Ft.t At_most_one.t }
    [@@deriving sexp, to_yojson]

    type diff =
      pre_diff_with_at_most_two_coinbase
      * pre_diff_with_at_most_one_coinbase option
    [@@deriving sexp, to_yojson]

    type t = {diff: diff; creator: Public_key.Compressed.t}
    [@@deriving sexp, to_yojson]

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
        Coda_compile_config.coinbase
end

include Make (Transaction_snark_work)
