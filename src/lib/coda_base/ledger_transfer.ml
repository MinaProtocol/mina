open Core_kernel
open Signature_lib

module type Base_ledger_intf =
  Merkle_ledger.Base_ledger_intf.S
  with type account := Account.t
   and type key := Public_key.Compressed.t
   and type hash := Ledger_hash.t
   and type root_hash := Ledger_hash.t

module Make (Source : Base_ledger_intf) (Dest : Base_ledger_intf) :
  Protocols.Coda_pow.Ledger_transfer_intf
  with type src := Source.t
   and type dest := Dest.t = struct
  let transfer_accounts ~src ~dest =
    let l = Ledger.create () in
    [%test_result: Ledger_hash.t]
      ~message:
        "Merkle root of an empty ledger is different from merkle root of the \
         fresh dest"
      ~expect:(Ledger.merkle_root l) (Dest.merkle_root dest) ;
    let sorted =
      Source.foldi src ~init:[] ~f:(fun addr acc account ->
          (addr, account) :: acc )
      |> List.sort ~compare:(fun (addr1, _) (addr2, _) ->
             Source.Addr.compare addr1 addr2 )
    in
    List.iter sorted ~f:(fun (addr, account) ->
        let key = Account.public_key account in
        ignore (Dest.get_or_create_account_exn dest key account) ) ;
    [%test_result: Ledger_hash.t] ~message:"Merkle roots differ after transfer"
      ~expect:(Source.merkle_root src) (Dest.merkle_root dest) ;
    dest
end
