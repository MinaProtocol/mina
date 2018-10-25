open Core_kernel
open Snark_params.Tick
open Fold_lib
open Tuple_lib
open Common

module Private_key = struct
  module type S = sig
    type t

    include Binable.S with type t := t

    include Sexpable.S with type t := t

    val create : unit -> t

    val gen : t Quickcheck.Generator.t

    val to_curve_scalar : t -> Inner_curve.Scalar.t

    val to_bigstring : t -> Bigstring.t

    val of_bigstring_exn : Bigstring.t -> t

    val to_base64 : t -> string

    val of_base64_exn : string -> t
  end
end

module Public_key = struct
  module Minimal = struct
    module type S = sig
      include Protocol_object.Hashable.S

      val empty : t
    end
  end

  module Base = struct
    module type S = sig
      module Private_key : Private_key.S

      module Stable : sig
        module V1 : Protocol_object.Hashable.S
      end

      include Minimal.S with type t = Stable.V1.t

      include Snarkable.S with type value := t

      val var_of_t : t -> var

      val of_private_key_exn : Private_key.t -> t

      val of_bigstring : Bigstring.t -> t Or_error.t

      val to_bigstring : t -> Bigstring.t

      val to_curve_pair : t -> Field.t * Field.t
    end
  end

  module Compressed = struct
    module Object = struct
      module type S = sig
        type t

        include Comparable.S with type t := t

        include Protocol_object.Full.S with type t := t
      end
    end

    module type S = sig
      type ('field, 'boolean) t_ = {x: 'field; is_odd: 'boolean}

      type t = (Field.t, bool) t_

      include Object.S with type t := t

      module Stable : sig
        module V1 : Protocol_object.Full.S with type t = t
      end

      include Protocol_object.Full.S with type t := t

      include Hashable.S_binable with type t := t

      include Snarkable.S
              with type value := t
               and type var = (Field.var, Boolean.var) t_

      val gen : t Quickcheck.Generator.t

      val empty : t

      val length_in_triples : int

      val var_of_t : t -> var

      val fold : t -> bool Triple.t Fold.t

      val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

      val of_base64_exn : string -> t

      val to_base64 : t -> string

      module Checked : sig
        val equal : var -> var -> (Boolean.var, _) Checked.t

        module Assert : sig
          val equal : var -> var -> (unit, _) Checked.t
        end
      end
    end
  end

  module type S = sig
    include Base.S

    module Compressed : Compressed.S

    val compress : t -> Compressed.t

    val decompress : Compressed.t -> t option

    val decompress_exn : Compressed.t -> t

    val compress_var : var -> (Compressed.var, _) Checked.t

    val decompress_var : Compressed.var -> (var, _) Checked.t
  end
end

module Keypair = struct
  module type S = sig
    module Private_key : Private_key.S

    module Public_key : Public_key.S

    type t = {public_key: Public_key.t; private_key: Private_key.t}

    val create : unit -> t

    val of_private_key_exn : Private_key.t -> t

    val private_key : t -> Private_key.t

    val public_key : t -> Public_key.t
  end
end

module Message = struct
  module type S = sig
    module Payload : sig
      type t

      type var
    end

    type var

    val var_of_payload : Payload.var -> (var, _) Checked.t

    val hash : Payload.t -> nonce:bool list -> Inner_curve.Scalar.t

    val hash_checked :
      var -> nonce:Boolean.var list -> (Inner_curve.Scalar.var, _) Checked.t
  end
end

module type S = sig
  type 'a shifted = (module Inner_curve.Checked.Shifted.S with type t = 'a)

  module Message : Message.S

  module Signature : sig
    include Protocol_object.Hashable.S
            with type t = Inner_curve.Scalar.t * Inner_curve.Scalar.t

    type var = Inner_curve.Scalar.var * Inner_curve.Scalar.var

    val typ : (var, t) Typ.t
  end

  (* TODO: unify keys with primary interfaces *)

  module Private_key : sig
    type t = Inner_curve.Scalar.t
  end

  module Public_key : sig
    type t = Inner_curve.t

    type var = Inner_curve.var
  end

  module Checked : sig
    val compress : Inner_curve.var -> (Boolean.var list, _) Checked.t

    val verification_hash :
         't shifted
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> (Inner_curve.Scalar.var, _) Checked.t

    val verifies :
         't shifted
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> (Boolean.var, _) Checked.t

    val assert_verifies :
         't shifted
      -> Signature.var
      -> Public_key.var
      -> Message.var
      -> (unit, _) Checked.t
  end

  val compress : Inner_curve.t -> bool list

  val sign : Private_key.t -> Message.Payload.t -> Signature.t

  val shamir_sum :
       Inner_curve.Scalar.t * Inner_curve.t
    -> Inner_curve.Scalar.t * Inner_curve.t
    -> Inner_curve.t

  val verify : Signature.t -> Public_key.t -> Message.Payload.t -> bool
end
