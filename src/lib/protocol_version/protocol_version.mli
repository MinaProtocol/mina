include
  Protocol_version_intf.Full
    with type Stable.V2.t = Mina_wire_types.Protocol_version.V2.t

type var

module Checked : sig
  open Snark_params.Tick

  val to_input :
    var -> Random_oracle.Checked.Digest.t Random_oracle.Input.Chunked.t

  val if_ : Boolean.var -> then_:var -> else_:var -> var Checked.t

  val constant : t -> var

  val equal_to_current : var -> Boolean.var Checked.t

  val older_than_current : var -> Boolean.var Checked.t

  type t = var
end

val typ : (Checked.t, t) Snark_params.Tick.Typ.t

val to_input : t -> Snark_params.Tick.Field.t Random_oracle.Input.Chunked.t
