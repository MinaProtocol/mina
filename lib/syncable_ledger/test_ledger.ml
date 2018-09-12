open Core
open Unsigned

module Make (Inputs : sig
  val depth : int

  val num_accts : int
end) =
struct
  open Merkle_ledger_tests.Test_stubs

  module Root_hash = struct
    include Hash

    let to_hash = Fn.id

    let empty_hash = empty

    type account = Account.t
  end

  module L = struct
    include Merkle_ledger.Ledger.Make (Key) (Account) (Hash) (Inputs)

    type path = Path.t

    type addr = Addr.t

    type account = Account.t

    type hash = Root_hash.t

    let load_ledger n b =
      let ledger = create () in
      let keys = List.init n ~f:(fun i -> Int.to_string i) in
      List.iter keys ~f:(fun k ->
          ignore
          @@ get_or_create_account_exn ledger k
               {Account.balance= UInt64.of_int b; public_key= k} ) ;
      (ledger, keys)
  end

  module SL =
    Syncable_ledger.Make (L.Addr) (Account) (Root_hash) (Root_hash) (L)
      (struct
        let subtree_height = 3
      end)

  module SR = SL.Responder

  let num_accts = Inputs.num_accts
end
