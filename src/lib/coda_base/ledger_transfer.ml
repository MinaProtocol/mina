open Core_kernel
open Signature_lib

module type Base_ledger_intf =
  Merkle_ledger.Base_ledger_intf.S
  with type account := Account.t
   and type key := Public_key.Compressed.t
   and type key_set := Public_key.Compressed.Set.t
   and type hash := Ledger_hash.t
   and type root_hash := Ledger_hash.t

module Make (Source : Base_ledger_intf) (Dest : Base_ledger_intf) : sig
  val transfer_accounts : src:Source.t -> dest:Dest.t -> Dest.t Or_error.t
end = struct
  let transfer_accounts ~src ~dest =
    let sorted =
      Source.foldi src ~init:[] ~f:(fun addr acc account ->
          (addr, account) :: acc )
      |> List.sort ~compare:(fun (addr1, _) (addr2, _) ->
             Source.Addr.compare addr1 addr2 )
    in
    List.iter sorted ~f:(fun (_addr, account) ->
        let key = Account.public_key account in
        ignore (Dest.get_or_create_account_exn dest key account) ) ;
    if not (Ledger_hash.equal (Source.merkle_root src) (Dest.merkle_root dest))
    then Or_error.error_string "Merkle roots differ after transfer"
    else Ok dest
end
