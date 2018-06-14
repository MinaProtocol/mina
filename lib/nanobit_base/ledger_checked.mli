open Snarky
open Snark_params
open Tick

type path = Pedersen.Digest.t list

type _ Request.t +=
  | Get_path: Account.Index.t -> path Request.t
  | Get_element: Account.Index.t -> (Account.t * path) Request.t
  | Set: Account.Index.t * Account.t -> unit Request.t
  | Find_index: Public_key.Compressed.t -> Account.Index.t Request.t

val modify_account :
     Ledger_hash.var
  -> Public_key.Compressed.var
  -> f:(Account.var -> (Account.var, 's) Checked.t)
  -> (Ledger_hash.var, 's) Checked.t

val create_account :
     Ledger_hash.var
  -> Public_key.Compressed.var
  -> (Ledger_hash.var, _) Checked.t
