open Core_kernel
open Mina_base
open Mina_state

let transactions_impl ~get_transactions ~constraint_constants header
    staged_ledger_diff =
  let consensus_state =
    Header.protocol_state header |> Protocol_state.consensus_state
  in
  let coinbase_receiver =
    Consensus.Data.Consensus_state.coinbase_receiver consensus_state
  in
  let supercharge_coinbase =
    Consensus.Data.Consensus_state.supercharge_coinbase consensus_state
  in
  get_transactions ~constraint_constants ~coinbase_receiver
    ~supercharge_coinbase staged_ledger_diff
  |> Result.map_error ~f:Staged_ledger.Pre_diff_info.Error.to_error
  |> Or_error.ok_exn

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

    let transactions ~constraint_constants block =
      transactions_impl
        ~get_transactions:Staged_ledger.Pre_diff_info.get_transactions_stable
        ~constraint_constants block.header
        (Staged_ledger_diff.Body.Stable.Latest.staged_ledger_diff block.body)

    module Creatable = struct
      let id = "block"

      type nonrec t = t

      type 'a creator =
        header:Header.t -> body:Staged_ledger_diff.Body.Stable.Latest.t -> 'a

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

module Serializable_type = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { header : Header.Stable.V2.t
        ; body : Staged_ledger_diff.Body.Serializable_type.Stable.V1.t
        }
      [@@deriving fields]

      let to_latest = Fn.id

      let transactions ~constraint_constants block =
        transactions_impl
          ~get_transactions:
            Staged_ledger.Pre_diff_info.get_transactions_serializable
          ~constraint_constants block.header block.body.staged_ledger_diff

      module Creatable = struct
        let id = "block"

        type nonrec t = t

        type 'a creator =
             header:Header.t
          -> body:Staged_ledger_diff.Body.Serializable_type.Stable.Latest.t
          -> 'a

        let map_creator c ~f ~header ~body = f (c ~header ~body)

        let create ~header ~body = { header; body }
      end

      include (
        Allocation_functor.Make.Basic
          (Creatable) :
            Allocation_functor.Intf.Output.Basic_intf
              with type t := t
               and type 'a creator := 'a Creatable.creator )
    end
  end]
end

type t = { header : Header.t; body : Staged_ledger_diff.Body.t }
[@@deriving fields]

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

let create ~header ~body = { header; body }

let wrap_with_hash block =
  With_hash.of_data block
    ~hash_data:
      ( Fn.compose Protocol_state.hashes
      @@ Fn.compose Header.protocol_state header )

let timestamp block =
  block |> header |> Header.protocol_state |> Protocol_state.blockchain_state
  |> Blockchain_state.timestamp

let transactions ~constraint_constants block =
  transactions_impl
    ~get_transactions:Staged_ledger.Pre_diff_info.get_transactions
    ~constraint_constants block.header
    (Staged_ledger_diff.Body.staged_ledger_diff block.body)

let account_ids_accessed ~constraint_constants t =
  let transactions = transactions ~constraint_constants t in
  List.map transactions ~f:(fun { data = txn; status } ->
      Mina_transaction.Transaction.account_access_statuses txn status )
  |> List.concat
  |> List.dedup_and_sort
       ~compare:[%compare: Account_id.t * [ `Accessed | `Not_accessed ]]

let write_all_proofs_to_disk ~signature_kind ~proof_cache_db
    { Stable.Latest.header; body } =
  { header
  ; body =
      Staged_ledger_diff.Body.write_all_proofs_to_disk ~signature_kind
        ~proof_cache_db body
  }

let read_all_proofs_from_disk { header; body } =
  { Stable.Latest.header
  ; body = Staged_ledger_diff.Body.read_all_proofs_from_disk body
  }

let to_serializable_type { header; body } : Serializable_type.t =
  { header; body = Staged_ledger_diff.Body.to_serializable_type body }
