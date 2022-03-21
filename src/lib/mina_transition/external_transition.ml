open Core_kernel
open Mina_base
open Mina_state

(* this module exists only as a stub to keep the bin_io for external transition from changing *)
module Validate_content = struct
  type t = unit

  let bin_read_t buf ~pos_ref =
    bin_read_unit buf ~pos_ref

  let bin_write_t buf ~pos _ = bin_write_unit buf ~pos ()

  let bin_shape_t = bin_shape_unit

  let bin_size_t _ = bin_size_unit ()

  let t_of_sexp _ = ()

  let sexp_of_t _ = sexp_of_unit ()

  let compare _ _ = 0

  let __versioned__ = ()
end

(* do not expose refer to types in here directly; use allocation functor version instead *)
module Raw_versioned__ = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { protocol_state : Protocol_state.Value.Stable.V1.t
        ; protocol_state_proof : Proof.Stable.V1.t [@sexp.opaque]
        ; staged_ledger_diff : Staged_ledger_diff.Stable.V1.t
        ; delta_transition_chain_proof :
            State_hash.Stable.V1.t * State_body_hash.Stable.V1.t list
        ; current_protocol_version : Protocol_version.Stable.V1.t
        ; proposed_protocol_version_opt : Protocol_version.Stable.V1.t option
        ; mutable validation_callback : Validate_content.t
        }
      [@@deriving compare, sexp, fields]

      let to_latest = Fn.id

      type 'a creator =
           protocol_state:Protocol_state.Value.t
        -> protocol_state_proof:Proof.t
        -> staged_ledger_diff:Staged_ledger_diff.t
        -> delta_transition_chain_proof:State_hash.t * State_body_hash.t list
        -> validation_callback:Validate_content.t
        -> ?proposed_protocol_version_opt:Protocol_version.t
        -> unit
        -> 'a

      let map_creator c ~f ~protocol_state ~protocol_state_proof
          ~staged_ledger_diff ~delta_transition_chain_proof ~validation_callback
          ?proposed_protocol_version_opt () =
        f
          (c ~protocol_state ~protocol_state_proof ~staged_ledger_diff
             ~delta_transition_chain_proof ~validation_callback
             ?proposed_protocol_version_opt ())

      let create ~protocol_state ~protocol_state_proof ~staged_ledger_diff
          ~delta_transition_chain_proof ~validation_callback
          ?proposed_protocol_version_opt () =
        let current_protocol_version =
          try Protocol_version.get_current ()
          with _ ->
            failwith
              "Cannot create external transition before setting current \
               protocol version"
        in
        { protocol_state
        ; protocol_state_proof
        ; staged_ledger_diff
        ; delta_transition_chain_proof
        ; current_protocol_version
        ; proposed_protocol_version_opt
        ; validation_callback
        }
    end
  end]
end

include Allocation_functor.Make.Versioned_v1.Sexp (struct
  let id = "external_transition"

  include Raw_versioned__
end)

[%%define_locally
Raw_versioned__.(protocol_state, current_protocol_version, proposed_protocol_version_opt, compare)]

[%%define_locally Stable.Latest.(create, sexp_of_t, t_of_sexp)]

let to_yojson t =
  `Assoc
    [ ("protocol_state", Protocol_state.value_to_yojson (protocol_state t))
    ; ("protocol_state_proof", `String "<opaque>")
    ; ("staged_ledger_diff", `String "<opaque>")
    ; ("delta_transition_chain_proof", `String "<opaque>")
    ; ( "current_protocol_version"
      , `String (Protocol_version.to_string (current_protocol_version t)) )
    ; ( "proposed_protocol_version"
      , `String
          (Option.value_map
             (proposed_protocol_version_opt t)
             ~default:"<None>" ~f:Protocol_version.to_string) )
    ]

let decompose
  { Raw_versioned__.Stable.V1.protocol_state
  ; protocol_state_proof
  ; staged_ledger_diff
  ; delta_transition_chain_proof
  ; current_protocol_version = _
  ; proposed_protocol_version_opt
  ; validation_callback = ()
  }
=
  let open Mina_block in
  let body = Body.create staged_ledger_diff in
  let body_reference = Body_reference.of_body body in
  let header = 
    Header.create
      ~protocol_state ~protocol_state_proof ~delta_block_chain_proof:delta_transition_chain_proof
      ?proposed_protocol_version_opt ~body_reference ()
  in
  create ~header ~body

let compose block =
  let create_transition = create in
  let open Mina_block in
  let b = body block in
  let h = header block in
  create_transition
    ~protocol_state:(Header.protocol_state h)
    ~protocol_state_proof:(Header.protocol_state_proof h)
    ~staged_ledger_diff:(Body.staged_ledger_diff b)
    ~delta_transition_chain_proof:(Header.delta_block_chain_proof h)
    ?proposed_protocol_version_opt:(Header.proposed_protocol_version_opt h)
    ~validation_callback:()
    ()

module Validated = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        (Stable.V1.t, State_hash.Stable.V1.t) With_hash.Stable.V1.t
        * State_hash.Stable.V1.t Non_empty_list.Stable.V1.t
      [@@deriving sexp]

      let to_yojson (transition, _) = With_hash.to_yojson to_yojson State_hash.to_yojson transition

      let to_latest = Fn.id
    end
  end]

  [%%define_locally
  Stable.Latest.(to_yojson)]

  let lift validated_block =
    let transition = validated_block |> Mina_block.Validated.forget |> With_hash.map ~f:compose in
    let delta_block_chain_proof = Mina_block.Validated.delta_block_chain_proof validated_block in
    (transition, delta_block_chain_proof)

  let lower (transition, delta_block_chain_proof) =
    let block = With_hash.map transition ~f:decompose in
    Mina_block.Validated.unsafe_of_trusted_block ~delta_block_chain_proof (`This_block_is_trusted_to_be_safe block)
end
