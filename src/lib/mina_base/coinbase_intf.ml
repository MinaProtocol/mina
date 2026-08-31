open Core
open Mina_base_import

module type Full = sig
  module Fee_transfer = Coinbase_fee_transfer

  module Stable : sig
    module V2 : sig
      type t = private
        { receiver : Public_key.Compressed.Stable.V1.t
        ; amount : Currency.Amount.Stable.V1.t
        ; fee_transfer : Fee_transfer.Stable.V1.t option
        ; fee_remainder : Currency.Fee.Stable.V1.t
        }
      [@@deriving sexp, bin_io, compare, equal, version, hash, yojson]
    end

    module Latest = V2
  end

  (* bin_io intentionally omitted in deriving list *)
  type t = Stable.Latest.t = private
    { receiver : Public_key.Compressed.t
    ; amount : Currency.Amount.t
    ; fee_transfer : Fee_transfer.t option
    ; fee_remainder : Currency.Fee.t
    }
  [@@deriving sexp, compare, equal, hash, yojson]

  include Codable.Base58_check_intf with type t := t

  val receiver_pk : t -> Public_key.Compressed.t

  val receiver : t -> Account_id.t

  val fee_payer_pk : t -> Public_key.Compressed.t

  val amount : t -> Currency.Amount.t

  val fee_transfer : t -> Fee_transfer.t option

  val account_access_statuses :
       t
    -> Transaction_status.t
    -> (Account_id.t * [ `Accessed | `Not_accessed ]) list

  val accounts_referenced : t -> Account_id.t list

  val fee_remainder : t -> Currency.Fee.t

  (** The total amount credited by the coinbase: the minted [amount] plus the
      fee excess it discharges. *)
  val total_credited : t -> Currency.Amount.t Or_error.t

  val create :
       amount:Currency.Amount.t
    -> receiver:Public_key.Compressed.t
    -> fee_transfer:Fee_transfer.t option
    -> fee_remainder:Currency.Fee.t
    -> t Or_error.t

  val expected_supply_increase : t -> Currency.Amount.t Or_error.t

  val fee_excess : t -> Fee_excess.t Or_error.t

  module Gen : sig
    val gen :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> (t * [ `Supercharged_coinbase of bool ]) Quickcheck.Generator.t

    (** Creates coinbase with reward between [min_amount] and [max_amount]. The generated amount[coinbase_amount] is then used as the upper bound for the fee transfer. *)
    val with_random_receivers :
         keys:Signature_keypair.t array
      -> min_amount:int
      -> max_amount:int
      -> fee_transfer:
           (   coinbase_amount:Currency.Amount.t
            -> Fee_transfer.t Quickcheck.Generator.t )
      -> t Quickcheck.Generator.t
  end
end
