open Core_kernel
open Snark_params.Tick
open Common

module Depth = struct
  module type S = sig
    val t : int
  end
end

module Hash = struct
  module type S = sig
    module Account : Account_intf.S

    type t = private Pedersen.Digest.t
    include Protocol_object.Full.S with type t := t

    val empty : t

    val merge : height:int -> t -> t -> t

    val of_account : Account.t -> t

    val of_digest : Pedersen.Digest.t -> t
  end
end

module Direction = struct
  module type S = sig
    type t = Left | Right
    include Equal.S with type t := t
    include Sexpable.S with type t := t

    val map : left:'a -> right:'a -> t -> 'a

    val to_bool : t -> bool
    val of_bool : bool -> t

    val to_int : t -> int
    val of_int : int -> t option
    val of_int_exn : int -> t

    val flip : t -> t

    val gen : t Quickcheck.Generator.t
    val gen_var_length_list : ?start:int -> int -> t list Quickcheck.Generator.t
    val gen_list : int -> t list Quickcheck.Generator.t
    val shrinker : t Quickcheck.Shrinker.t
  end
end

module Address = struct
  module type S = sig
    module Direction : Direction.S

    module Stable : sig
      module V1 : Protocol_object.Full.S
    end

    include Protocol_object.Full.S with type t = Stable.V1.t
    include Hashable.S with type t := t

    val of_byte_string : string -> t

    val of_directions : Direction.t list -> t

    val root : unit -> t

    val slice : t -> int -> int -> t

    val get : t -> int -> int

    val copy : t -> t

    val parent : t -> t Or_error.t

    val child : t -> Direction.t -> t Or_error.t

    val child_exn : t -> Direction.t -> t

    val parent_exn : t -> t

    val dirs_from_root : t -> Direction.t list

    val sibling : t -> t

    val next : t -> t Option.t

    val is_parent_of : t -> maybe_child:t -> bool

    val serialize : t -> Bigstring.t

    val pp : Format.formatter -> t -> unit

    module Range : sig
      type nonrec t = t * t

      val fold :
           ?stop:[`Inclusive | `Exclusive]
        -> t
        -> init:'a
        -> f:(Stable.V1.t -> 'a -> 'a)
        -> 'a

      val subtree_range : Stable.V1.t -> t
    end

    val depth : t -> int

    val height : t -> int

    val to_int : t -> int

    val of_int_exn : int -> t
  end
end

module Path = struct
  module type S = sig
    module Direction : Direction.S
    module Hash : Hash.S

    module Elem : sig
      type t = Direction.t * Hash.t
      include Sexpable.S with type t := t
    end

    type t = Elem.t list
    include Sexpable.S with type t := t

    val implied_root : t -> Hash.t -> Hash.t
  end
end

module Location = struct
  module type S = sig
    type t
  end
end

module Base = struct
  module type S = sig
    module Depth : Depth.S
    module Account : Account_intf.S
    module Root_hash : Ledger_hash_intf.S
    module Hash : Hash.S
      with module Account = Account
    module Address : Address.S
    module Path : Path.S
      with module Hash = Hash
       and module Direction = Address.Direction
    module Location : Location.S

    include Binable.S
    include Sexpable.S with type t := t

    type error =
      | Account_location_not_found
      | Out_of_leaves
      | Malformed_database

    val location_of_key : t -> Account.Compressed_public_key.t -> Location.t option

    val get_or_create_account_exn : t -> Account.Compressed_public_key.t -> Account.t -> ([`Added | `Existed] * Location.t, error) Result.t

    val create : unit -> t

    val depth : int

    val num_accounts : t -> int

    val merkle_root : t -> Root_hash.t

    val to_list : t -> Account.t list

    val fold_until :
         t
      -> init:'accum
      -> f:('accum -> Account.t -> ('accum, 'stop) Base.Continue_or_stop.t)
      -> finish:('accum -> 'stop)
      -> 'stop

    val get : t -> Location.t -> Account.t option

    val set : t -> Location.t -> Account.t -> unit

    val get_at_index_exn : t -> int -> Account.t

    val get_inner_hash_at_addr_exn : t -> Address.t -> Hash.t

    val get_all_accounts_rooted_at_exn : t -> Address.t -> Account.t list

    val set_at_index_exn : t -> int -> Account.t -> unit

    val set_inner_hash_at_addr_exn : t -> Address.t -> Hash.t -> unit

    val set_all_accounts_rooted_at_exn : t -> Address.t -> Account.t list -> unit

    val index_of_key_exn : t -> Account.Compressed_public_key.t -> int

    val merkle_path : t -> Location.t -> Path.t

    val merkle_path_at_addr_exn : t -> Address.t -> Path.t

    val merkle_path_at_index_exn : t -> int -> Path.t

    val remove_accounts_exn : t -> Account.Compressed_public_key.t list -> unit

    val make_space_for : t -> int -> unit

    val copy : t -> t

    (* TODO: hide *)
    module For_tests : sig
      val get_leaf_hash_at_addr : t -> Address.t -> Hash.t
    end
  end
end

module Undo = struct
  (* TODO: decompose and generalize undo signature *)
  (*
  module Base = struct
    module type S = sig
      include Binable.S
      include Sexpable.S with type t := t

      val previous_empty_accounts : t -> Public_key.Compressed.t list
    end
  end

  module Payment = struct
    module type S = sig
      module Payment : Transaction_intf.Payment.S

      include Binable.S
      include Sexpable.S with type t := t

      val payment : t -> Payment.t
    end
  end
 *)

  module type S = sig
    module Keypair : Signature_intf.Keypair.S
    module Payment : Transaction_intf.Payment.S
      with module Keypair = Keypair
    module Transaction : Transaction_intf.S
      with module Valid_payment = Payment.With_valid_signature
    module Receipt_chain_hash : Account_intf.Receipt_chain_hash.S
    module Ledger_hash : Ledger_hash_intf.S

    type payment =
      { payment: Payment.t
      ; previous_empty_accounts: Keypair.Public_key.Compressed.t list
      ; previous_receipt_chain_hash: Receipt_chain_hash.t }
    [@@deriving sexp, bin_io]

    type fee_transfer =
      { fee_transfer: Transaction.Fee_transfer.t
      ; previous_empty_accounts: Keypair.Public_key.Compressed.t list }
    [@@deriving sexp, bin_io]

    type coinbase =
      { coinbase: Transaction.Coinbase.t
      ; previous_empty_accounts: Keypair.Public_key.Compressed.t list }
    [@@deriving sexp, bin_io]

    type varying =
      | Payment of payment
      | Fee_transfer of fee_transfer
      | Coinbase of coinbase
    [@@deriving sexp, bin_io]

    type t = {previous_hash: Ledger_hash.t; varying: varying}
    [@@deriving sexp, bin_io]

    val super_transaction : t -> Transaction.t Or_error.t
  end
end

module type S = sig
  include Base.S

  module Keypair : Signature_intf.Keypair.S
    with module Public_key.Compressed = Account.Compressed_public_key
  module Payment : Transaction_intf.Payment.S
    with module Keypair = Keypair
  module Transaction : Transaction_intf.S
    with module Valid_payment = Payment.With_valid_signature
  module Ledger_hash : Ledger_hash_intf.S

  module Undo : Undo.S
    with module Keypair = Keypair
     and module Payment = Payment
     and module Transaction = Transaction
     and module Ledger_hash = Ledger_hash

  val create_empty : t -> Keypair.Public_key.Compressed.t -> Path.t * Account.t

  val create_new_account_exn : t -> Keypair.Public_key.Compressed.t -> Account.t -> unit

  val apply_payment : t -> Payment.t -> Undo.payment Or_error.t

  val apply_super_transaction : t -> Transaction.t -> Undo.t Or_error.t

  val undo : t -> Undo.t -> unit Or_error.t

  val merkle_root_after_transaction_exn : t -> Payment.With_valid_signature.t -> Ledger_hash.t
end

module Genesis = struct
  module type S = sig
    module Ledger : S
    val t : Ledger.t
  end
end
