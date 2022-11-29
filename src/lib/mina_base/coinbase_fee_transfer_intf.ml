open Core_kernel
open Mina_base_import

module type Full = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = private
        { receiver_pk : Public_key.Compressed.Stable.V1.t
        ; fee : Currency.Fee.Stable.V1.t
        }
      [@@deriving sexp, compare, equal, yojson, hash]
    end
  end]

  val create : receiver_pk:Public_key.Compressed.t -> fee:Currency.Fee.t -> t

  include Comparable.S with type t := t

  include Codable.Base58_check_intf with type t := t

  val receiver_pk : t -> Public_key.Compressed.t

  val receiver : t -> Account_id.t

  val fee : t -> Currency.Fee.t

  val to_fee_transfer : t -> Fee_transfer.Single.t

  module Gen : sig
    (** [gen ?min_fee max_fee] generates fee transfers between [min_fee] and
        [max_fee].

        @param min_fee defaults to zero *)
    val gen :
      ?min_fee:Currency.Fee.t -> Currency.Fee.t -> t Quickcheck.Generator.t

    (** [with_random_receivers ~key ?min_fee coinbase_amount] creates coinbase
        fee transfers with fees between [min_fee] and [coinbase_amount]

        @param min_fee defaults to {!val:Currency.Fee.zero}
     *)
    val with_random_receivers :
         keys:Signature_keypair.t array
      -> ?min_fee:Currency.Fee.t
      -> Currency.Amount.t
      -> t Quickcheck.Generator.t
  end
end
