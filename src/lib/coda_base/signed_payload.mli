open Tuple_lib
open Fold_lib
open Import

type ('payload, 'pk, 'signature) t_ =
  {payload: 'payload; sender: 'pk; signature: 'signature}
[@@deriving bin_io, eq, sexp, hash]

type 'payload t = ('payload, Public_key.t, Signature.t) t_
[@@deriving bin_io, eq, sexp, hash]

type 'payload var = ('payload, Public_key.var, Signature.var) t_

module Stable : sig
  module V1 : sig
    type nonrec ('payload, 'pk, 'signature) t_ = ('payload, 'pk, 'signature) t_
[@@deriving bin_io, eq, sexp, hash]
    type 'payload t = ('payload, Public_key.Stable.V1.t, Signature.Stable.V1.t) t_
[@@deriving bin_io, eq, sexp, hash]
  end
end

module With_valid_signature : sig
  type nonrec 'payload t = private 'payload t
  [@@deriving sexp, eq, bin_io]
end

module type S = sig
  open Snark_params.Tick

  module Payload : sig
    type t type var end

  type nonrec t = Payload.t t
  [@@deriving bin_io, eq, sexp, hash]

  type nonrec var = Payload.var var

  val typ : (var, t) Typ.t

  module With_valid_signature : sig
    type nonrec t = private t
    [@@deriving sexp, eq, bin_io]
  end

  val sign : Signature_keypair.t -> Payload.t -> With_valid_signature.t

  val check : t -> With_valid_signature.t option

  module Section : sig
    type t = private Pedersen.Checked.Section.t

    val create : Payload.var -> (t, _) Checked.t
  end

  module Checked : sig
    val verifies :
         (module Inner_curve.Checked.Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Section.t
      -> (Boolean.var, _) Checked.t

    val assert_verifies :
         (module Inner_curve.Checked.Shifted.S with type t = 't)
      -> Signature.var
      -> Public_key.var
      -> Section.t
      -> (unit, _) Checked.t
  end
end

module Make
    (Prefix : sig
       val t : Snark_params.Tick.Pedersen.State.t
     end)
    (Payload : sig
       open Snark_params.Tick

       type t [@@deriving sexp, bin_io, eq, hash]

       type var

       val typ : (var, t) Typ.t

       val fold : t -> bool Triple.t Fold.t

       val length_in_triples : int

       module Checked : sig
         val to_triples : var -> (Boolean.var Triple.t list, _) Checked.t
       end
     end) : S with module Payload := Payload

