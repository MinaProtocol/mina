open Core_kernel
open Mina_base
open Mina_state

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      { header : Header.Stable.V2.t
      ; body : Staged_ledger_diff.Body.Stable.V1.t
      }
    [@@deriving fields, sexp]

    let to_latest = Fn.id

    module Creatable = struct
      let id = "block"

      type nonrec t = t

      type 'a creator = header:Header.t -> body:Staged_ledger_diff.Body.t -> 'a

      let map_creator c ~f ~header ~body = f (c ~header ~body)

      let create ~header ~body = { header; body }
    end

    let equal =
      Comparable.lift Consensus.Data.Consensus_state.Value.equal
        ~f:
          (Fn.compose Mina_state.Protocol_state.consensus_state
             (Fn.compose Header.protocol_state header) )

    include (
      Allocation_functor.Make.Basic
        (Creatable) :
          Allocation_functor.Intf.Output.Basic_intf
            with type t := t
             and type 'a creator := 'a Creatable.creator )
  end
end]

type t = Stable.Latest.t =
  { header : Header.t; body : Staged_ledger_diff.Body.t }

type with_hash = t State_hash.With_state_hashes.t

let to_logging_yojson header : Yojson.Safe.t =
  `Assoc
    [ ( "protocol_state"
      , Protocol_state.value_to_yojson (Header.protocol_state header) )
    ; ("protocol_state_proof", `String "<opaque>")
    ; ("staged_ledger_diff", `String "<opaque>")
    ; ("delta_transition_chain_proof", `String "<opaque>")
    ; ( "current_protocol_version"
      , `String
          (Protocol_version.to_string (Header.current_protocol_version header))
      )
    ; ( "proposed_protocol_version"
      , `String
          (Option.value_map
             (Header.proposed_protocol_version_opt header)
             ~default:"<None>" ~f:Protocol_version.to_string ) )
    ]

[%%define_locally Stable.Latest.(create, header, body)]

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
  let staged_ledger_diff =
    block |> body |> Staged_ledger_diff.Body.staged_ledger_diff
  in
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

let account_ids_accessed ~constraint_constants t =
  let transactions = transactions ~constraint_constants t in
  List.map transactions ~f:(fun { data = txn; status } ->
      Mina_transaction.Transaction.account_access_statuses txn status )
  |> List.concat
  |> List.dedup_and_sort
       ~compare:[%compare: Account_id.t * [ `Accessed | `Not_accessed ]]
