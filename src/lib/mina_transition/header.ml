open Core_kernel
open Mina_base
open Mina_state

(* CHANGES:
     - remove staged ledger diff
     - added body reference
     - removed mutable validation callback as field in header
*)

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { protocol_state : Protocol_state.Value.Stable.V2.t
      ; protocol_state_proof : Proof.Stable.V2.t [@sexp.opaque]
      ; delta_block_chain_proof :
          (* TODO: abstract *)
          State_hash.Stable.V1.t * State_body_hash.Stable.V1.t list
      ; current_protocol_version : Protocol_version.Stable.V1.t
      ; proposed_protocol_version_opt : Protocol_version.Stable.V1.t option
      ; body_reference : Body_reference.Stable.V1.t
      }
    [@@deriving compare, fields, sexp, to_yojson]

    let to_latest = Fn.id

    module Creatable = struct
      let id = "block_header"

      type nonrec t = t

      let sexp_of_t = sexp_of_t

      let t_of_sexp = t_of_sexp

      type 'a creator =
           protocol_state:Protocol_state.Value.t
        -> protocol_state_proof:Proof.t
        -> delta_block_chain_proof:State_hash.t * State_body_hash.t list
        -> body_reference:Body_reference.t
        -> ?proposed_protocol_version_opt:Protocol_version.t
        -> ?current_protocol_version:Protocol_version.t
        -> unit
        -> 'a

      let map_creator c ~f ~protocol_state ~protocol_state_proof
          ~delta_block_chain_proof ~body_reference
          ?proposed_protocol_version_opt ?current_protocol_version () =
        f
          (c ~protocol_state ~protocol_state_proof ~delta_block_chain_proof
             ~body_reference ?proposed_protocol_version_opt
             ?current_protocol_version ())

      let create ~protocol_state ~protocol_state_proof ~delta_block_chain_proof
          ~body_reference ?proposed_protocol_version_opt
          ?current_protocol_version () =
        let cur_ver_fun =
          Option.(bind current_protocol_version ~f:(Fn.compose return const))
        in
        let cur_ver_fallback () =
          try Protocol_version.get_current ()
          with _ ->
            failwith
              "Cannot create block header before setting current protocol \
               version"
        in
        { protocol_state
        ; protocol_state_proof
        ; delta_block_chain_proof
        ; current_protocol_version =
            Option.value ~default:cur_ver_fallback cur_ver_fun ()
        ; proposed_protocol_version_opt
        ; body_reference
        }
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

[%%define_locally
Stable.Latest.
  ( protocol_state
  , protocol_state_proof
  , delta_block_chain_proof
  , current_protocol_version
  , proposed_protocol_version_opt
  , body_reference
  , compare
  , create
  , sexp_of_t
  , t_of_sexp
  , to_yojson )]

type protocol_version_status =
  { valid_current : bool; valid_next : bool; matches_daemon : bool }

let protocol_version_status body =
  let valid_current =
    Protocol_version.is_valid (current_protocol_version body)
  in
  let valid_next =
    Option.for_all
      (proposed_protocol_version_opt body)
      ~f:Protocol_version.is_valid
  in
  let matches_daemon =
    Protocol_version.compatible_with_daemon (current_protocol_version body)
  in
  { valid_current; valid_next; matches_daemon }
