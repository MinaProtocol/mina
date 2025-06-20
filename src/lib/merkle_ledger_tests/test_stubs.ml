open Core

module Balance = struct
  include Currency.Balance

  let to_int = to_nanomina_int

  let of_int = of_nanomina_int_exn
end

module Receipt = Mina_base.Receipt
module Intf = Merkle_ledger.Intf

module In_memory_kvdb : Intf.Key_value_database with type config := string =
struct
  module Bigstring_frozen = struct
    module T = struct
      include Bigstring.Stable.V1

      (* we're not mutating Bigstrings, which would invalidate hashes
         OK to use these hash functions
      *)
      let hash = hash_t_frozen

      let hash_fold_t = hash_fold_t_frozen
    end

    include T
    include Hashable.Make_binable (T)
  end

  type t =
    { uuid : Uuid.Stable.V1.t
    ; table : Bigstring_frozen.t Bigstring_frozen.Table.t
    }
  [@@deriving sexp]

  let to_alist t =
    let unsorted = Bigstring_frozen.Table.to_alist t.table in
    (* sort by key *)
    List.sort
      ~compare:(fun (k1, _) (k2, _) -> Bigstring_frozen.compare k1 k2)
      unsorted

  let get_uuid t = t.uuid

  let create _ =
    { uuid = Uuid_unix.create (); table = Bigstring_frozen.Table.create () }

  let create_checkpoint t _ =
    { uuid = Uuid_unix.create (); table = Bigstring_frozen.Table.copy t.table }

  let close _ = ()

  let get t ~key = Bigstring_frozen.Table.find t.table key

  let get_batch t ~keys = List.map keys ~f:(Bigstring_frozen.Table.find t.table)

  let set t ~key ~data = Bigstring_frozen.Table.set t.table ~key ~data

  let set_batch t ?(remove_keys = []) ~key_data_pairs =
    List.iter key_data_pairs ~f:(fun (key, data) -> set t ~key ~data) ;
    List.iter remove_keys ~f:(fun key ->
        Bigstring_frozen.Table.remove t.table key )

  let remove t ~key = Bigstring_frozen.Table.remove t.table key

  let make_checkpoint _ _ = ()

  let foldi t ~init ~f =
    let i = ref (-1) in
    let f ~key ~data accum = incr i ; f !i accum ~key ~data in
    Bigstring_frozen.Table.fold t.table ~init ~f

  (* Relying on {!val:to_alist} is probably enough for testing purposes. *)
  let fold_until t ~init ~f ~finish =
    let f accum (key, data) = f accum ~key ~data in
    let alist = to_alist t in
    List.fold_until alist ~init ~f ~finish
end

module Storage_locations : Intf.Storage_locations = struct
  (* TODO: The name of this value should be dynamically generated per test run*)
  let key_value_db_dir = ""
end

module Key : sig
  include Merkle_ledger.Intf.Key with type t = Mina_base.Account.Key.t

  val gen : t Base_quickcheck.Generator.t

  val gen_keys : int -> t list
end = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Mina_base.Account.Key.Stable.V1.t
      [@@deriving sexp, equal, compare, hash]

      let to_latest = Fn.id
    end
  end]

  let to_string = Signature_lib.Public_key.Compressed.to_base58_check

  let gen = Mina_base.Account.key_gen

  let empty : t = Mina_base.Account.empty.public_key

  let gen_keys num_keys =
    Quickcheck.random_value (Quickcheck.Generator.list_with_length num_keys gen)

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)
end

module Token_id = Mina_base.Token_id

module Account_id : sig
  include
    Merkle_ledger.Intf.Account_id
      with type token_id := Mina_base.Token_id.t
       and type key := Key.t

  val gen : t Base_quickcheck.Generator.t

  val gen_accounts : int -> t list

  val eq :
    (Mina_wire_types.Mina_base_account_id.M.V2.t, t) Core_kernel.Type_equal.t

  val eq2 : (Mina_base.Account_id.t, t) Core_kernel.Type_equal.t
end = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Mina_base.Account_id.Stable.V2.t
      [@@deriving sexp, equal, compare, hash]

      let to_latest = Fn.id
    end
  end]

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)

  let create = Mina_base.Account_id.create

  let token_id = Mina_base.Account_id.token_id

  let public_key = Mina_base.Account_id.public_key

  let derive_token_id = Mina_base.Account_id.derive_token_id

  (* TODO: Non-default tokens *)
  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map pk = Key.gen in
    create pk Token_id.default

  let gen_accounts num_accounts =
    Quickcheck.random_value
      (Quickcheck.Generator.list_with_length num_accounts gen)

  let eq = Core_kernel.Type_equal.T

  let eq2 = Core_kernel.Type_equal.T
end

module Account : sig
  include
    Merkle_ledger.Intf.Account
      with type token_id := Token_id.t
       and type account_id := Account_id.t
       and type balance := Balance.t
       and type t = Mina_base.Account.t

  val gen : t Base_quickcheck.Generator.t

  val create : Mina_base.Account_id.t -> Balance.t -> t

  val update_balance : t -> Balance.t -> t

  val public_key : t -> Mina_base.Account.Key.t

  val of_yojson : Yojson.Safe.t -> (t, string) Result.t

  val to_yojson : t -> Yojson.Safe.t
end = struct
  (* want bin_io, not available with Account.t *)
  type t = Mina_base.Account.Stable.Latest.t
  [@@deriving bin_io_unversioned, sexp, equal, compare, hash, yojson]

  (* use Account items needed *)
  let empty = Mina_base.Account.empty

  let public_key = Mina_base.Account.public_key

  let gen = Mina_base.Account.gen

  let create = Mina_base.Account.create

  let balance Mina_base.Account.{ balance; _ } = balance

  let update_balance t bal = { t with Mina_base.Account.balance = bal }

  let token Mina_base.Account.{ token_id; _ } = token_id

  let identifier ({ public_key; token_id; _ } : t) =
    Account_id.create public_key token_id
end

module Hash_arg = struct
  type t = Md5.t [@@deriving sexp, hash, compare, bin_io_unversioned, equal]
end

module Hash = struct
  module T = struct
    type t = Md5.t [@@deriving sexp, hash, compare, bin_io_unversioned, equal]
  end

  include T

  let (_ : (t, Hash_arg.t) Type_equal.t) = Type_equal.T

  include Codable.Make_base58_check (struct
    type t = T.t [@@deriving bin_io_unversioned]

    let description = "Ledger test hash"

    let version_byte = Base58_check.Version_bytes.ledger_test_hash
  end)

  include Hashable.Make_binable (Hash_arg)

  (* to prevent pre-image attack,
   * important impossible to create an account such that (merge a b = hash_account account) *)

  let hash_account account =
    Md5.digest_string (Format.sprintf !"0%{sexp: Account.t}" account)

  let merge ~height a b =
    let res =
      Md5.digest_string
        (sprintf "test_ledger_%d:%s%s" height (Md5.to_hex a) (Md5.to_hex b))
    in
    res

  let empty_account = hash_account Account.empty
end

module Make_base_inputs
    (Account : Merkle_ledger.Intf.Account
                 with type account_id := Account_id.t
                  and type token_id := Token_id.t
                  and type balance := Balance.t)
    (Hash : Merkle_ledger.Intf.Hash with type account := Account.t) =
struct
  module Key = Key
  module Account_id = Account_id
  module Token_id = Token_id

  module Balance = struct
    include Balance

    let of_int = of_nanomina_int_exn

    let to_int = to_nanomina_int
  end

  module Account = Account
  module Hash = Hash
end

module Base_inputs = Make_base_inputs (Account) (Hash)
