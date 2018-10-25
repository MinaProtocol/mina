open Core_kernel
open Currency
open Fold_lib
open Tuple_lib
open Snark_params.Tick
open Coda_numbers
open Common

module Payment = struct
  module Payload = struct
    module type Base = sig
      module Compressed_public_key : Signature_intf.Public_key.Compressed.S

      type t

      module Stable : sig
        module V1 : Protocol_object.Hashable.S with type t = t
      end

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

    module type S = sig
      module Compressed_public_key : Signature_intf.Public_key.Compressed.S

      type ('pk, 'amount, 'fee, 'nonce) t_ =
        {receiver: 'pk; amount: 'amount; fee: 'fee; nonce: 'nonce}

      include Base
              with module Compressed_public_key := Compressed_public_key
               and type t =
                          ( Compressed_public_key.Stable.V1.t
                          , Currency.Amount.Stable.V1.t
                          , Currency.Fee.Stable.V1.t
                          , Coda_numbers.Account_nonce.Stable.V1.t )
                          t_
               and type var =
                          ( Compressed_public_key.var
                          , Currency.Amount.var
                          , Currency.Fee.var
                          , Coda_numbers.Account_nonce.Unpacked.var )
                          t_
    end
  end

  module Object = struct
    module type S = sig
      include Protocol_object.S

      val seeded_compare : seed:string -> t -> t -> int
    end
  end

  module With_valid_signature = struct
    module type S = sig
      include Object.S
    end
  end

  module Object_with_valid_signature = struct
    module type S = sig
      module Compressed_public_key :
        Signature_intf.Public_key.Compressed.Object.S

      include Object.S

      module With_valid_signature :
        With_valid_signature.S with type t = private t
    end
  end

  module For_ledger_builder = struct
    module type S = sig
      include Object_with_valid_signature.S

      val fee : t -> Currency.Fee.t

      val check : t -> With_valid_signature.t option

      val public_keys : t -> Compressed_public_key.t list
    end
  end

  module Base = struct
    module type S = sig
      type ('payload, 'pk, 'signature) t_ =
        {payload: 'payload; sender: 'pk; signature: 'signature}

      module Compressed_public_key : Signature_intf.Public_key.Compressed.S

      module Public_key :
        Signature_intf.Public_key.S
        with module Compressed = Compressed_public_key

      module Payload :
        Payload.S with module Compressed_public_key = Public_key.Compressed

      module Signature : Signature_intf.S

      include Object.S
              with type t = (Payload.t, Public_key.t, Signature.Signature.t) t_

      val payload : t -> Payload.t

      val sender : t -> Public_key.t

      val signature : t -> Signature.Signature.t
    end
  end

  module type S = sig
    module Keypair : Signature_intf.Keypair.S

    include Base.S
            with module Compressed_public_key = Keypair.Public_key.Compressed
             and module Public_key = Keypair.Public_key

    module Stable : sig
      module V1 :
        Object.S
        with type t =
                    ( Payload.Stable.V1.t
                    , Keypair.Public_key.Stable.V1.t
                    , Signature.Signature.t )
                    t_
    end

    include Snarkable.S
            with type value := t
             and type var =
                        ( Payload.var
                        , Keypair.Public_key.var
                        , Signature.Signature.var )
                        t_

    val gen :
         keys:Keypair.t array
      -> max_amount:int
      -> max_fee:int
      -> t Quickcheck.Generator.t

    module With_valid_signature :
      With_valid_signature.S with type t = private t

    val check : t -> With_valid_signature.t option

    val sign : Keypair.t -> Payload.t -> With_valid_signature.t

    val public_keys : t -> Keypair.Public_key.Compressed.t list
  end
end

module Fee_transfer = struct
  module type S = sig
    module Compressed_public_key :
      Signature_intf.Public_key.Compressed.Object.S

    type single = Compressed_public_key.t * Fee.t
    [@@deriving sexp, bin_io, compare, eq]

    type t = One of single | Two of single * single

    include Protocol_object.Comparable.S with type t := t

    val of_single : single -> t

    val of_single_list : single list -> t list

    val to_single_list : t -> single list

    val receivers : t -> Compressed_public_key.t list

    val fee_excess : t -> Fee.Signed.t Or_error.t
  end
end

module Coinbase = struct
  module type S = sig
    module Fee_transfer : Fee_transfer.S

    type t = private
      { proposer: Fee_transfer.Compressed_public_key.t
      ; amount: Currency.Amount.t
      ; fee_transfer: Fee_transfer.single option }

    include Protocol_object.Comparable.S with type t := t

    val create :
         amount:Amount.t
      -> proposer:Fee_transfer.Compressed_public_key.t
      -> fee_transfer:Fee_transfer.single option
      -> t Or_error.t

    val supply_increase : t -> Amount.t Or_error.t

    val fee_excess : t -> Fee.Signed.t Or_error.t
  end
end

module Base = struct
  module type S = sig
    module Compressed_public_key :
      Signature_intf.Public_key.Compressed.Object.S

    module Payment :
      Payment.Object_with_valid_signature.S
      with module Compressed_public_key = Compressed_public_key

    module Fee_transfer :
      Fee_transfer.S with module Compressed_public_key = Compressed_public_key

    module Coinbase : Coinbase.S with module Fee_transfer = Fee_transfer

    type t =
      | Valid_payment of Payment.With_valid_signature.t
      | Fee_transfer of Fee_transfer.t
      | Coinbase of Coinbase.t

    include Protocol_object.S with type t := t

    val fee_excess : t -> Fee.Signed.t Or_error.t

    val supply_increase : t -> Amount.t Or_error.t
  end
end

module For_ledger_builder = struct
  module type S = sig
    module Compressed_public_key :
      Signature_intf.Public_key.Compressed.Object.S

    module Payment :
      Payment.For_ledger_builder.S
      with module Compressed_public_key = Compressed_public_key

    include Base.S
            with module Compressed_public_key := Compressed_public_key
             and module Payment := Payment
  end
end

module type S = sig
  module Public_key : Signature_intf.Public_key.S

  module Payment : Payment.S with module Keypair.Public_key = Public_key

  module Fee_transfer :
    Fee_transfer.S with module Compressed_public_key = Public_key.Compressed

  module Coinbase : Coinbase.S with module Fee_transfer = Fee_transfer

  include Base.S
          with module Compressed_public_key := Public_key.Compressed
           and module Payment := Payment
           and module Fee_transfer := Fee_transfer
           and module Coinbase := Coinbase
end
