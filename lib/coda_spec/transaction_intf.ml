open Core_kernel
open Currency
open Fold_lib
open Tuple_lib
open Snark_params.Tick
open Coda_numbers

module Payment = struct
  module Payload = struct
    module type S = sig
      module Compressed_public_key : Signature_intf.Public_key.Compressed.S

      module Stable : sig
        module V1 : sig
          type t [@@deriving hash]
          include Binable.S with type t := t
          include Equal.S with type t := t
          include Sexpable.S with type t := t
        end
      end

      type t = Stable.V1.t [@@deriving hash]
      include Binable.S with type t := t
      include Equal.S with type t := t
      include Sexpable.S with type t := t

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

  module With_valid_signature = struct
    module type S = sig
      type t
      include Sexpable.S with type t := t
      include Equal.S with type t := t
      val compare : t -> t -> int

      val gen :
           keys:Keypair.t array
        -> max_amount:int
        -> max_fee:int
        -> t Quickcheck.Generator.t
    end
  end

  module type S = sig
    module Keypair : Signature_intf.Keypair.S
    module Payload : Payload.S
      with module Compressed_public_key = Keypair.Public_key.Compressed
    module Signature : Signature_intf.S

    module Stable : sig
      module V1 : sig
        type t
      end
    end

    type t = Stable.V1.t

    include Sexpable.S with type t := t
    include Equal.S with type t := t
    include Binable.S with type t := t
    val compare : t -> t -> int

    val payload : t -> Payload.t
    val sender : t -> Keypair.Public_key.t
    val signature : t -> Signature.Signature.t

    include Snarkable.S with type value := t

    module With_valid_signature : With_valid_signature.S
      with type t = private t

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
    module Public_key : Signature_intf.Public_key.S

    type t [@@deriving sexp, compare, eq]

    type single = Public_key.t * Fee.t

    val of_single : single -> t

    val of_single_list : single list -> t list

    val receivers : t -> Public_key.t list
  end
end

module Coinbase = struct
  module type S = sig
    module Public_key : Signature_intf.Public_key.S
    module Fee_transfer : Fee_transfer.S
      with module Public_key = Public_key

    type t [@@deriving sexp, compare, eq, bin_io]

    val create :
         amount:Amount.t
      -> proposer:Public_key.t
      -> fee_transfer:Fee_transfer.t option
      -> t Or_error.t
  end
end

module type S = sig
  module Valid_payment : Payment.With_valid_signature.S
  module Fee_transfer : Fee_transfer.S
  module Coinbase : Coinbase.S
    with module Public_key = Fee_transfer.Public_key
     and module Fee_transfer = Fee_transfer

  type t =
    | Valid_payment of Valid_payment.t
    | Fee_transfer of Fee_transfer.t
    | Coinbase of Coinbase.t
  [@@deriving sexp, compare, eq, bin_io]

  val fee_excess : t -> Fee.t Or_error.t

  val supply_increase : t -> Amount.t Or_error.t
end
