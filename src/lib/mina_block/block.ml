open Core_kernel
open Mina_base
open Mina_state

[%%versioned
module Stable = struct
  module V1 = struct
    type t = { header : Header.Stable.V1.t; body : Body.Stable.V1.t }
    [@@deriving compare, fields, sexp]

    let to_yojson t =
      `Assoc
        [ ( "protocol_state"
          , Protocol_state.value_to_yojson (Header.protocol_state t.header) )
        ; ("protocol_state_proof", `String "<opaque>")
        ; ("staged_ledger_diff", `String "<opaque>")
        ; ("delta_transition_chain_proof", `String "<opaque>")
        ; ( "current_protocol_version"
          , `String
              (Protocol_version.to_string
                 (Header.current_protocol_version t.header) ) )
        ; ( "proposed_protocol_version"
          , `String
              (Option.value_map
                 (Header.proposed_protocol_version_opt t.header)
                 ~default:"<None>" ~f:Protocol_version.to_string ) )
        ]

    let to_latest = Fn.id

    module Creatable = struct
      let id = "block"

      type nonrec t = t

      let sexp_of_t = sexp_of_t

      let t_of_sexp = t_of_sexp

      type 'a creator = header:Header.t -> body:Body.t -> 'a

      let map_creator c ~f ~header ~body = f (c ~header ~body)

      let create ~header ~body = { header; body }
    end

    include (
      Allocation_functor.Make.Basic
        (Creatable) :
          Allocation_functor.Intf.Output.Basic_intf
            with type t := t
             and type 'a creator := 'a Creatable.creator )

    include (
      Allocation_functor.Make.Sexp
        (Creatable) :
          Allocation_functor.Intf.Output.Sexp_intf
            with type t := t
             and type 'a creator := 'a Creatable.creator )
  end
end]

type with_hash = t State_hash.With_state_hashes.t [@@deriving sexp]

[%%define_locally
Stable.Latest.(create, compare, header, body, t_of_sexp, sexp_of_t, to_yojson)]

let wrap_with_hash block =
  With_hash.of_data block
    ~hash_data:
      ( Fn.compose Protocol_state.hashes
      @@ Fn.compose Header.protocol_state header )

let timestamp block =
  block |> header |> Header.protocol_state |> Protocol_state.blockchain_state
  |> Blockchain_state.timestamp

let transactions ~constraint_constants block =
  let consensus_state =
    block |> header |> Header.protocol_state |> Protocol_state.consensus_state
  in
  let staged_ledger_diff = block |> body |> Body.staged_ledger_diff in
  let coinbase_receiver =
    Consensus.Data.Consensus_state.coinbase_receiver consensus_state
  in
  let supercharge_coinbase =
    Consensus.Data.Consensus_state.supercharge_coinbase consensus_state
  in
  Staged_ledger.Pre_diff_info.get_transactions ~constraint_constants
    ~coinbase_receiver ~supercharge_coinbase staged_ledger_diff
  |> Result.map_error ~f:Staged_ledger.Pre_diff_info.Error.to_error
  |> Or_error.ok_exn

let payments block =
  block |> body |> Body.staged_ledger_diff |> Staged_ledger_diff.commands
  |> List.filter_map ~f:(function
       | { data = Signed_command ({ payload = { body = Payment _; _ }; _ } as c)
         ; status
         } ->
           Some { With_status.data = c; status }
       | _ ->
           None )

let equal =
  Comparable.lift Consensus.Data.Consensus_state.Value.equal
    ~f:
      (Fn.compose Mina_state.Protocol_state.consensus_state
         (Fn.compose Header.protocol_state header) )

let account_ids_accessed t =
  let transactions =
    transactions
      ~constraint_constants:Genesis_constants.Constraint_constants.compiled t
  in
  List.map transactions ~f:(fun { data = txn; _ } ->
      Mina_transaction.Transaction.accounts_accessed txn )
  |> List.concat
  |> List.dedup_and_sort ~compare:Account_id.compare
