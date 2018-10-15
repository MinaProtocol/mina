open Core_kernel
open Currency

module Payment = struct
  module With_valid_signature = struct
    module type S = sig
      type t [@@deriving sexp, compare, eq]
    end
  end

  module type S = sig
    module Public_key : Signature_intf.Public_key.S

    type t [@@deriving sexp, compare, eq, bin_io]

    module With_valid_signature : With_valid_signature.S
      with type t = private t

    val check : t -> With_valid_signature.t option

    val fee : t -> Fee.t

    val sender : t -> Public_key.t

    val receiver : t -> Public_key.t
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
