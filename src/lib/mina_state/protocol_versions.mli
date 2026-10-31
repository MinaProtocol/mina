(** The protocol versions recorded in a block's blockchain state: the version
    of the protocol that produced the block, and the version its producer
    proposes to upgrade to, if any. Recording them in the protocol state lets
    the block proof commit to them, so they can't be altered in transit. *)

open Snark_params.Tick

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('version, 'proposed) t =
            ( 'version
            , 'proposed )
            Mina_wire_types.Mina_state.Protocol_versions.Poly.V1.t =
        { current : 'version; proposed : 'proposed }
      [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
    end
  end]
end

module Value : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        ( Protocol_version.Stable.V2.t
        , Protocol_version.Stable.V2.t option )
        Poly.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]
    end
  end]
end

module Version : sig
  type var

  val typ : (var, Protocol_version.t) Typ.t
end

type var =
  ( Version.var
  , (Boolean.var, Version.var) Mina_base.Zkapp_basic.Flagged_option.t )
  Poly.t

val typ : (var, Value.t) Typ.t

val create :
  current:Protocol_version.t -> proposed:Protocol_version.t option -> Value.t

(** The daemon's own versions: {!Protocol_version.current} and the proposed
    version it was configured with. *)
val of_daemon : unit -> Value.t

(** The versions given to states from before they were recorded, which have no
    proposal and are assigned the last protocol version without the field. *)
val legacy : Value.t

val to_input : Value.t -> Field.t Random_oracle.Input.Chunked.t

val var_to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t

(** Assert that the current version has the transaction and network versions of
    this circuit's protocol. The patch version is not constrained, since patch
    releases keep the same circuit. *)
val assert_current_is_this_protocol : var -> unit Checked.t
