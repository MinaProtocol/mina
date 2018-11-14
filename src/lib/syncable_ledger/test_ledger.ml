open Core

module Make (Inputs : sig
  val depth : int
end) =
struct
  open Merkle_ledger_tests.Test_stubs

  module Root_hash = struct
    include Hash

    let to_hash = Fn.id

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
      let keys = Merkle_ledger_tests.Test_stubs.Key.gen_keys n in
      let balance = Currency.Balance.of_int b in
      List.iter keys ~f:(fun public_key ->
          ignore
          @@ get_or_create_account_exn ledger public_key
               (Account.create public_key balance) ) ;
      (ledger, keys)
  end

  module SL =
    Syncable_ledger.Make (L.Addr) (Account) (Root_hash) (Root_hash) (L)
      (struct
        let subtree_height = 3
      end)

  module SR = SL.Responder
end
