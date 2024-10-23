open Core_kernel
open Mina_base
open Mina_state

[%%versioned
module Stable = struct
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

      let sexp_of_t = sexp_of_t

      let t_of_sexp = t_of_sexp

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

    include (
      Allocation_functor.Make.Sexp
        (Creatable) :
          Allocation_functor.Intf.Output.Sexp_intf
            with type t := t
             and type 'a creator := 'a Creatable.creator )
  end
end]

type with_hash =
  (Header.t * Staged_ledger_diff.With_hashes_computed.t)
  State_hash.With_state_hashes.t
[@@deriving sexp]

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

[%%define_locally Stable.Latest.(create, header, body, t_of_sexp, sexp_of_t)]

let with_hash_to_yojson =
  State_hash.With_state_hashes.to_yojson
  @@ fun (h, b) ->
  let body =
    Staged_ledger_diff.With_hashes_computed.forget b
    |> Staged_ledger_diff.Body.create
  in
  to_yojson @@ create ~header:h ~body

let staged_ledger_diff_hashed b =
  Staged_ledger_diff.With_hashes_computed.compute
  @@ Staged_ledger_diff.Body.staged_ledger_diff b.body

let wrap_with_hash block : with_hash =
  With_hash.of_data block
    ~hash_data:
      ( Fn.compose Protocol_state.hashes
      @@ Fn.compose Header.protocol_state header )
  |> With_hash.map ~f:(fun b -> (b.header, staged_ledger_diff_hashed b))

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
  Staged_ledger.Pre_diff_info.get_transactions_exn ~constraint_constants
    ~consensus_state staged_ledger_diff.diff

let block_of_header_and_body_with_hashes (header, body_hashed) =
  create ~header
    ~body:
      ( Staged_ledger_diff.Body.create
      @@ Staged_ledger_diff.With_hashes_computed.forget body_hashed )

let forget_computed_hashes =
  With_hash.map ~f:block_of_header_and_body_with_hashes
