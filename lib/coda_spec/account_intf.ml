open Core_kernel
open Currency
open Snark_bits
open Snark_params.Tick
open Coda_numbers

module Index = struct
  module type S = sig
    type t
    include Binable.S with type t := t

    module Vector : sig
      type t

      val empty : t

      val length : int

      val get : t -> int -> bool

      val set : t -> int -> bool -> t
    end

    include Bits_intf.S with type t := t
    include Bits_intf.Snarkable.Small
      with type ('a, 'b) typ := ('a, 'b) Typ.t
       and type ('a, 'b) checked := ('a, 'b) Checked.t
       and type boolean_var := Boolean.var
       and type Packed.var = Field.Checked.t
       and type Packed.value = Vector.t
       and type Unpacked.var = Boolean.var list
       and type Unpacked.value = Vector.t
       and type comparison_result := Field.Checked.comparison_result

    val to_int : t -> int

    val of_int : int -> t
  end
end

module Receipt_chain_hash = struct
  module type S = sig
    module Payment_payload : Transaction_intf.Payment.Payload.S

    include Hash_intf.Full_size.S

    val empty : t

    val cons : Payment_payload.t -> t -> t

    module Checked : sig
      val constant : t -> var
      val cons : payload:Pedersen.Checked.Section.t -> var -> (var, _) Checked.t
    end
  end
end

module type S = sig
  module Receipt_chain_hash : Hash_intf.Full_size.S
  module Compressed_public_key : Signature_intf.Public_key.Compressed.S

  module Index : Index.S

  module Stable : sig
    module V1 : sig
      type t
      include Binable.S with type t := t
      include Equal.S with type t := t
      include Sexpable.S with type t := t
    end
  end

  type t = Stable.V1.t
  include Binable.S with type t := t
  include Equal.S with type t := t
  include Sexpable.S with type t := t

  val create :
       public_key:Compressed_public_key.t
    -> balance:Balance.t
    -> nonce:Account_nonce.t
    -> receipt_chain_hash:Receipt_chain_hash.t
    -> t

  val public_key : t -> Compressed_public_key.t
  val balance : t -> Balance.t
  val nonce : t -> Account_nonce.t
  val receipt_chain_hash : t -> Receipt_chain_hash.t

  type value = t [@@deriving sexp]
  type var
  include Snarkable.S with type value := value and type var := var

  val create_var :
       public_key:Compressed_public_key.var
    -> balance:Balance.var
    -> nonce:Account_nonce.Unpacked.var
    -> receipt_chain_hash:Receipt_chain_hash.var
    -> var

  val var_public_key : var -> Compressed_public_key.var
  val var_balance : var -> Balance.var
  val var_nonce : var -> Account_nonce.Unpacked.var
  val var_receipt_chain_hash : var -> Receipt_chain_hash.var

  val empty : t
  val initialize : Compressed_public_key.t -> t

  (* TODO: introduce Account_hash? *)
  val hash : t -> Pedersen.State.t
  val empty_hash : Field.t

  val digest : t -> Field.t

  module Checked : sig
    val hash : var -> (Inner_curve.var, _) Checked.t
    val digest : var -> (Field.var, _) Checked.t
  end
end
