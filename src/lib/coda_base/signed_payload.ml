open Core
open Import
open Snark_params.Tick
open Tuple_lib
open Fold_lib

module Stable = struct
  module V1 = struct
    type ('payload, 'pk, 'signature) t_ =
      {payload: 'payload; sender: 'pk; signature: 'signature}
    [@@deriving bin_io, eq, sexp, hash]

    type 'payload t = ('payload, Public_key.Stable.V1.t, Signature.Stable.V1.t) t_
    [@@deriving bin_io, eq, sexp, hash]
  end
end

include Stable.V1

module With_valid_signature = Stable.V1

type 'payload var = ('payload, Public_key.var, Signature.var) t_

type 'a signed_payload = 'a t
[@@deriving bin_io, eq, sexp, hash]

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
       type t [@@deriving sexp, bin_io, eq, hash]
       type var
       val typ : (var, t) Snark_params.Tick.Typ.t

       val fold : t -> bool Triple.t Fold.t

       val length_in_triples : int

       module Checked : sig
         val to_triples : var -> (Boolean.var Triple.t list, _) Checked.t
       end
     end)
= struct
  module T = struct
    type t = Payload.t signed_payload
    [@@deriving bin_io, eq, sexp, hash]
  end
  include T

  type nonrec var = Payload.var var

  module Schnorr = Schnorr.Make(Prefix)(Payload)

  let typ : (var, t) Typ.t =
    let spec = Data_spec.[Payload.typ; Public_key.typ; Schnorr.Signature.typ] in
    let of_hlist
          : 'a 'b 'c. (unit, 'a -> 'b -> 'c -> unit) H_list.t -> ('a, 'b, 'c) t_ =
      H_list.(fun [payload; sender; signature] -> {payload; sender; signature})
    in
    let to_hlist {payload; sender; signature} =
      H_list.[payload; sender; signature]
    in
    Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  module With_valid_signature = T

  let sign (kp : Signature_lib.Keypair.t) (payload : Payload.t) : t =
    { payload
    ; sender= kp.public_key
    ; signature= Schnorr.sign kp.private_key payload }

  let check_signature ({payload; sender; signature}: t) =
    Schnorr.verify signature (Inner_curve.of_coords sender) payload

  let check t = Option.some_if (check_signature t) t

  module Section = struct
    type t = Pedersen.Checked.Section.t
    let create payload =
      let open Let_syntax in
      let%bind triples = Payload.Checked.to_triples payload in
      Pedersen.Checked.Section.extend Pedersen.Checked.Section.empty triples
        ~start:Hash_prefix.length_in_triples
  end

  module Checked = Schnorr.Checked
end

