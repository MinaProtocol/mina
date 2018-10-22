open Core_kernel
open Currency
open Fold_lib
open Tuple_lib
open Snark_params.Tick
open Coda_numbers
open Common

module Payment = struct
  module Payload = struct
    module type S = sig
      module Compressed_public_key : Signature_intf.Public_key.Compressed.S

      module Stable : sig
        module V1 : Protocol_object.Hashable.S
      end

      type t = Stable.V1.t
      include Protocol_object.Hashable.S with type t := t

      val dummy : t
      val gen : t Quickcheck.Generator.t

      val create :
           receiver:Compressed_public_key.t
        -> amount:Amount.t
        -> fee:Fee.t
        -> nonce:Account_nonce.t
        -> t
      val receiver : t -> Compressed_public_key.t
      val amount : t -> Amount.t
      val fee : t -> Fee.t
      val nonce : t -> Account_nonce.t

      include Snarkable.S with type value := t

      val length_in_triples : int

      val to_triples : t -> bool Triple.t list

      val fold : t -> bool Triple.t Fold.t

      val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

      val var_of_t : t -> var
    end
  end

  module Object = struct
    module type S = sig
      include Protocol_object.S
      val compare : seed:string -> t -> t -> int
    end
  end

  module Base = struct
    module type S = sig
      module Public_key : Signature_intf.Public_key.S
      module Payload : Payload.S
        with module Compressed_public_key = Public_key.Compressed
      module Signature : Signature_intf.S

      include Object.S

      val payload : t -> Payload.t
      val sender : t -> Public_key.t
      val signature : t -> Signature.Signature.t
    end
  end

  module With_valid_signature = struct
    module type S = Base.S
  end

  module type S = sig
    module Keypair : Signature_intf.Keypair.S

    module Stable : sig
      module V1 : Object.S
    end

    include Base.S
      with type t = Stable.V1.t
       and module Public_key := Keypair.Public_key
    include Snarkable.S with type value := t

    module With_valid_signature : With_valid_signature.S
      with type t = private t
       and module Public_key = Keypair.Public_key
       and module Payload = Payload
       and module Signature = Signature

    val gen :
         keys:Keypair.t array
      -> max_amount:int
      -> max_fee:int
      -> t Quickcheck.Generator.t

    val check : t -> With_valid_signature.t option

    val sign : Keypair.t -> Payload.t -> With_valid_signature.t

    val public_keys : t -> Keypair.Public_key.Compressed.t list
  end
end

module Fee_transfer = struct
  module type S = sig
    module Compressed_public_key : Signature_intf.Public_key.Compressed.S

    include Protocol_object.S

    type single = Compressed_public_key.t * Fee.t [@@deriving sexp, bin_io, compare, eq]

    val of_single : single -> t

    val of_single_list : single list -> t list

    val receivers : t -> Compressed_public_key.t list

    val fee_excess : t -> Fee.Signed.t Or_error.t
  end
end

module Coinbase = struct
  module type S = sig
    module Fee_transfer : Fee_transfer.S

    include Protocol_object.S

    val create :
         amount:Amount.t
      -> proposer:Fee_transfer.Compressed_public_key.t
      -> fee_transfer:Fee_transfer.single option
      -> t Or_error.t

    val supply_increase : t -> Amount.t Or_error.t

    val fee_excess : t -> Fee.Signed.t Or_error.t
  end
end

module type S = sig
  module Valid_payment : Payment.With_valid_signature.S
  module Fee_transfer : Fee_transfer.S
    with module Compressed_public_key = Valid_payment.Public_key.Compressed
  module Coinbase : Coinbase.S
    with module Fee_transfer = Fee_transfer

  type t =
    | Valid_payment of Valid_payment.t
    | Fee_transfer of Fee_transfer.t
    | Coinbase of Coinbase.t
  include Protocol_object.S with type t := t

  val fee_excess : t -> Fee.Signed.t Or_error.t

  val supply_increase : t -> Amount.t Or_error.t
end
