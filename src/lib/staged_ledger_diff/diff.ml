open Core_kernel
open Mina_base

module At_most_two = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
      [@@deriving equal, compare, sexp, yojson]
    end
  end]

  type 'a t = 'a Stable.Latest.t =
    | Zero
    | One of 'a option
    | Two of ('a * 'a option) option
  [@@deriving equal, compare, sexp, yojson]

  let increase t ws =
    match (t, ws) with
    | Zero, [] ->
        Ok (One None)
    | Zero, [ a ] ->
        Ok (One (Some a))
    | One _, [] ->
        Ok (Two None)
    | One _, [ a ] ->
        Ok (Two (Some (a, None)))
    | One _, [ a; a' ] ->
        Ok (Two (Some (a', Some a)))
    | _ ->
        Or_error.error_string "Error incrementing coinbase parts"
end

module At_most_one = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = Zero | One of 'a option
      [@@deriving equal, compare, sexp, yojson]
    end
  end]

  type 'a t = 'a Stable.Latest.t = Zero | One of 'a option
  [@@deriving equal, compare, sexp, yojson]

  let increase t ws =
    match (t, ws) with
    | Zero, [] ->
        Ok (One None)
    | Zero, [ a ] ->
        Ok (One (Some a))
    | _ ->
        Or_error.error_string "Error incrementing coinbase parts"
end

module Ft = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = Coinbase.Fee_transfer.Stable.V1.t
      [@@deriving equal, compare, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving equal, compare, sexp, yojson]
end

module Pre_diff_generic = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type ('a, 'b, 'coinbase) t =
        { completed_works : 'a list
        ; commands : 'b list
        ; coinbase : 'coinbase
        ; internal_command_statuses : Transaction_status.Stable.V2.t list
        }
      [@@deriving equal, compare, sexp, yojson]

      let extract_prediff t =
        (t.completed_works, t.commands, t.coinbase, t.internal_command_statuses)
    end
  end]

  type ('a, 'b, 'coinbase) t =
    { command_hashes : Mina_transaction.Transaction_hash.t list [@sexp.opaque]
    ; completed_works : 'a list
    ; commands : 'b list
    ; coinbase : 'coinbase
    ; internal_command_statuses : Transaction_status.t list
    }
  [@@deriving equal, compare, sexp_of, to_yojson]

  let extract_prediff t =
    (t.completed_works, t.commands, t.coinbase, t.internal_command_statuses)

  let write_all_proofs_to_disk ~signature_kind ~proof_cache_db
      ({ commands; completed_works; coinbase; internal_command_statuses } :
        ( Transaction_snark_work.Stable.Latest.t
        , User_command.Stable.Latest.t With_status.Stable.Latest.t
        , 'c )
        Stable.Latest.t ) :
      (Transaction_snark_work.t, User_command.t With_status.t, 'c) t =
    let write_sw =
      Transaction_snark_work.write_all_proofs_to_disk ~proof_cache_db
    in
    let write_tx =
      With_status.map
        ~f:
          (User_command.write_all_proofs_to_disk ~signature_kind ~proof_cache_db)
    in
    let hash_command =
      Fn.compose Mina_transaction.Transaction_hash.hash_command With_status.data
    in
    { commands = List.map ~f:write_tx commands
    ; completed_works = List.map ~f:write_sw completed_works
    ; coinbase
    ; internal_command_statuses
    ; command_hashes = List.map ~f:hash_command commands
    }

  let read_all_proofs_from_disk
      ({ commands
       ; completed_works
       ; coinbase
       ; internal_command_statuses
       ; command_hashes = _
       } :
        (Transaction_snark_work.t, User_command.t With_status.t, 'c) t ) :
      ( Transaction_snark_work.Stable.Latest.t
      , User_command.Stable.Latest.t With_status.Stable.Latest.t
      , 'c )
      Stable.Latest.t =
    let read_sw = Transaction_snark_work.read_all_proofs_from_disk in
    let read_tx = With_status.map ~f:User_command.read_all_proofs_from_disk in
    { commands = List.map ~f:read_tx commands
    ; completed_works = List.map ~f:read_sw completed_works
    ; coinbase
    ; internal_command_statuses
    }
end

module Pre_diff_two = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type ('a, 'b) t =
        ( 'a
        , 'b
        , Ft.Stable.V1.t At_most_two.Stable.V1.t )
        Pre_diff_generic.Stable.V2.t
      [@@deriving equal, compare, sexp, yojson]
    end
  end]

  type ('a, 'b) t = ('a, 'b, Ft.t At_most_two.t) Pre_diff_generic.t
  [@@deriving equal, compare, sexp_of, to_yojson]
end

module Pre_diff_one = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type ('a, 'b) t =
        ( 'a
        , 'b
        , Ft.Stable.V1.t At_most_one.Stable.V1.t )
        Pre_diff_generic.Stable.V2.t
      [@@deriving equal, compare, sexp, yojson]
    end
  end]

  type ('a, 'b) t = ('a, 'b, Ft.t At_most_one.t) Pre_diff_generic.t
  [@@deriving equal, compare, sexp_of, to_yojson]
end

module Pre_diff_with_at_most_two_coinbase = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        ( Transaction_snark_work.Stable.V2.t
        , User_command.Stable.V2.t With_status.Stable.V2.t )
        Pre_diff_two.Stable.V2.t
      [@@deriving equal, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t =
    (Transaction_snark_work.t, User_command.t With_status.t) Pre_diff_two.t

  [%%define_locally
  Pre_diff_generic.(read_all_proofs_from_disk, write_all_proofs_to_disk)]
end

module Pre_diff_with_at_most_one_coinbase = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        ( Transaction_snark_work.Stable.V2.t
        , User_command.Stable.V2.t With_status.Stable.V2.t )
        Pre_diff_one.Stable.V2.t
      [@@deriving equal, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t =
    (Transaction_snark_work.t, User_command.t With_status.t) Pre_diff_one.t

  [%%define_locally
  Pre_diff_generic.(read_all_proofs_from_disk, write_all_proofs_to_disk)]
end

module Diff = struct
  let coinbase_amount
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~supercharge_coinbase =
    if supercharge_coinbase then
      Currency.Amount.scale constraint_constants.coinbase_amount
        constraint_constants.supercharged_coinbase_factor
    else Some constraint_constants.coinbase_amount

  let coinbase
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~supercharge_coinbase (first_pre_diff, second_pre_diff_opt) =
    let coinbase_amount =
      coinbase_amount ~constraint_constants ~supercharge_coinbase
    in
    match
      ( first_pre_diff.Pre_diff_generic.coinbase
      , Option.value_map second_pre_diff_opt ~default:At_most_one.Zero
          ~f:(fun d -> d.Pre_diff_generic.coinbase) )
    with
    | At_most_two.Zero, At_most_one.Zero ->
        Some Currency.Amount.zero
    | _ ->
        coinbase_amount

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        Pre_diff_with_at_most_two_coinbase.Stable.V2.t
        * Pre_diff_with_at_most_one_coinbase.Stable.V2.t option
      [@@deriving equal, sexp, yojson]

      let to_latest = Fn.id

      let coinbase
          ~(constraint_constants : Genesis_constants.Constraint_constants.t)
          ~supercharge_coinbase (first_pre_diff, second_pre_diff_opt) =
        let coinbase_amount =
          coinbase_amount ~constraint_constants ~supercharge_coinbase
        in
        match
          ( first_pre_diff.Pre_diff_generic.Stable.Latest.coinbase
          , Option.value_map second_pre_diff_opt ~default:At_most_one.Zero
              ~f:(fun d -> d.Pre_diff_generic.Stable.Latest.coinbase) )
        with
        | At_most_two.Zero, At_most_one.Zero ->
            Some Currency.Amount.zero
        | _ ->
            coinbase_amount
    end
  end]

  type t =
    Pre_diff_with_at_most_two_coinbase.t
    * Pre_diff_with_at_most_one_coinbase.t option

  let write_all_proofs_to_disk ~signature_kind ~proof_cache_db
      (( pre_diff_with_at_most_two_coinbase
       , pre_diff_with_at_most_one_coinbase_opt ) :
        Stable.Latest.t ) : t =
    ( Pre_diff_with_at_most_two_coinbase.write_all_proofs_to_disk
        ~signature_kind ~proof_cache_db pre_diff_with_at_most_two_coinbase
    , Option.map pre_diff_with_at_most_one_coinbase_opt
        ~f:
          (Pre_diff_with_at_most_one_coinbase.write_all_proofs_to_disk
             ~signature_kind ~proof_cache_db ) )

  let read_all_proofs_from_disk
      (( pre_diff_with_at_most_two_coinbase
       , pre_diff_with_at_most_one_coinbase_opt ) :
        t ) : Stable.Latest.t =
    ( Pre_diff_with_at_most_two_coinbase.read_all_proofs_from_disk
        pre_diff_with_at_most_two_coinbase
    , Option.map pre_diff_with_at_most_one_coinbase_opt
        ~f:Pre_diff_with_at_most_one_coinbase.read_all_proofs_from_disk )
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t = { diff : Diff.Stable.V2.t } [@@deriving equal, sexp, yojson]

    let to_latest = Fn.id

    let empty_diff : t =
      { diff =
          ( { completed_works = []
            ; commands = []
            ; coinbase = At_most_two.Zero
            ; internal_command_statuses = []
            }
          , None )
      }

    let completed_works (t : t) =
      (fst t.diff).completed_works
      @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d ->
            d.completed_works )
  end
end]

type t = { diff : Diff.t } [@@deriving fields]

let write_all_proofs_to_disk ~signature_kind ~proof_cache_db t =
  { diff =
      Diff.write_all_proofs_to_disk ~signature_kind ~proof_cache_db
        t.Stable.Latest.diff
  }

let read_all_proofs_from_disk t =
  { Stable.Latest.diff = Diff.read_all_proofs_from_disk t.diff }

module With_valid_signatures_and_proofs = struct
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.Valid.t With_status.t )
    Pre_diff_two.t

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.Valid.t With_status.t )
    Pre_diff_one.t

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option

  type t = { diff : diff }

  let empty_diff : t =
    { diff =
        ( { completed_works = []
          ; commands = []
          ; coinbase = At_most_two.Zero
          ; internal_command_statuses = []
          ; command_hashes = []
          }
        , None )
    }

  let commands t =
    (fst t.diff).commands
    @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d -> d.commands)
end

let forget_cw cw_list = List.map ~f:Transaction_snark_work.forget cw_list

module With_valid_signatures = struct
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.t
    , User_command.Valid.t With_status.t )
    Pre_diff_two.t

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.t
    , User_command.Valid.t With_status.t )
    Pre_diff_one.t

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option

  type t = { diff : diff }

  let coinbase
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~supercharge_coinbase (t : t) =
    Diff.coinbase ~constraint_constants ~supercharge_coinbase t.diff
end

let validate_commands (t : t)
    ~(check :
          User_command.t With_status.t list
       -> Mina_transaction.Transaction_hash.t list
       -> (User_command.Valid.t list, 'e) Result.t Async.Deferred.Or_error.t ) :
    (With_valid_signatures.t, 'e) Result.t Async.Deferred.Or_error.t =
  let map t ~f = Async.Deferred.Or_error.map t ~f:(Result.map ~f) in
  let validate cs hashes =
    map (check cs hashes)
      ~f:
        (List.map2_exn cs ~f:(fun c data ->
             { With_status.data; status = c.status } ) )
  in
  let d1, d2 = t.diff in
  map
    (validate
       (d1.commands @ Option.value_map d2 ~default:[] ~f:(fun d2 -> d2.commands))
       ( d1.command_hashes
       @ Option.value_map d2 ~default:[] ~f:(fun d2 -> d2.command_hashes) ) )
    ~f:(fun commands_all ->
      let commands1, commands2 =
        List.split_n commands_all (List.length d1.commands)
      in
      let p1 : With_valid_signatures.pre_diff_with_at_most_two_coinbase =
        { completed_works = d1.completed_works
        ; commands = commands1
        ; coinbase = d1.coinbase
        ; internal_command_statuses = d1.internal_command_statuses
        ; command_hashes = d1.command_hashes
        }
      in
      let p2 =
        Option.value_map ~default:None d2 ~f:(fun d2 ->
            Some
              { Pre_diff_generic.completed_works = d2.completed_works
              ; commands = commands2
              ; coinbase = d2.coinbase
              ; internal_command_statuses = d2.internal_command_statuses
              ; command_hashes = d2.command_hashes
              } )
      in
      ({ diff = (p1, p2) } : With_valid_signatures.t) )

let forget_proof_checks (d : With_valid_signatures_and_proofs.t) :
    With_valid_signatures.t =
  let d1 = fst d.diff in
  let p1 : With_valid_signatures.pre_diff_with_at_most_two_coinbase =
    { completed_works = forget_cw d1.completed_works
    ; commands = d1.commands
    ; coinbase = d1.coinbase
    ; internal_command_statuses = d1.internal_command_statuses
    ; command_hashes = d1.command_hashes
    }
  in
  let p2 =
    Option.map (snd d.diff)
      ~f:(fun d2 : With_valid_signatures.pre_diff_with_at_most_one_coinbase ->
        { completed_works = forget_cw d2.completed_works
        ; commands = d2.commands
        ; coinbase = d2.coinbase
        ; internal_command_statuses = d2.internal_command_statuses
        ; command_hashes = d2.command_hashes
        } )
  in
  { diff = (p1, p2) }

let forget_pre_diff
    (pre_diff :
      ( Transaction_snark_work.Checked.t
      , User_command.Valid.t With_status.t
      , 'c )
      Pre_diff_generic.t ) :
    ( Transaction_snark_work.t
    , User_command.t With_status.t
    , 'c )
    Pre_diff_generic.t =
  { completed_works = forget_cw pre_diff.completed_works
  ; commands =
      List.map
        ~f:(With_status.map ~f:User_command.forget_check)
        pre_diff.commands
  ; coinbase = pre_diff.coinbase
  ; internal_command_statuses = pre_diff.internal_command_statuses
  ; command_hashes = pre_diff.command_hashes
  }

let forget (t : With_valid_signatures_and_proofs.t) =
  { diff =
      (forget_pre_diff (fst t.diff), Option.map (snd t.diff) ~f:forget_pre_diff)
  }

let commands (t : t) =
  (fst t.diff).commands
  @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d -> d.commands)

let command_hashes (t : t) =
  (fst t.diff).command_hashes
  @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d -> d.command_hashes)

let completed_works (t : t) =
  (fst t.diff).completed_works
  @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d -> d.completed_works)

let net_return
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~supercharge_coinbase (t : t) =
  let open Currency in
  let open Option.Let_syntax in
  let%bind coinbase =
    Diff.coinbase ~constraint_constants ~supercharge_coinbase t.diff
  in
  let%bind total_reward =
    List.fold
      ~init:(Some (Amount.to_fee coinbase))
      (commands t)
      ~f:(fun sum cmd ->
        let%bind sum = sum in
        Fee.( + ) sum (User_command.fee (With_status.data cmd)) )
  in
  let%bind completed_works_fees =
    List.fold ~init:(Some Fee.zero) (completed_works t) ~f:(fun sum work ->
        let%bind sum = sum in
        Fee.(sum + Transaction_snark_work.fee work) )
  in
  Amount.(of_fee total_reward - of_fee completed_works_fees)

let empty_diff : t =
  { diff =
      ( { completed_works = []
        ; commands = []
        ; coinbase = At_most_two.Zero
        ; internal_command_statuses = []
        ; command_hashes = []
        }
      , None )
  }

let is_empty = function
  | { diff =
        ( { completed_works = []
          ; commands = []
          ; coinbase = At_most_two.Zero
          ; internal_command_statuses = []
          ; command_hashes = []
          }
        , None )
    } ->
      true
  | _ ->
      false
