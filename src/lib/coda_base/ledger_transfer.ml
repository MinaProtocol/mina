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
    Source.foldi src ~init:dest ~f:(fun _addr dest account ->
        let key = Account.public_key account in
        ignore (Dest.get_or_create_account_exn dest key account) ;
        dest )
end
