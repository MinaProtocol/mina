open Snark_params.Tick

module type S = sig
  module Account : Account_intf.S
  module Compressed_public_key : Signature_intf.Public_key.Compressed.S

  include Hash_intf.Full_size.S

  type path = Pedersen.Digest.t list

  type _ Snarky.Request.t +=
    | Get_path: Account.Index.t -> path Snarky.Request.t
    | Get_element: Account.Index.t -> (Account.t * path) Snarky.Request.t
    | Set: Account.Index.t * Account.t -> unit Snarky.Request.t
    | Find_index: Compressed_public_key.t -> Account.Index.t Snarky.Request.t

  val modify_account_send :
       var
    -> Compressed_public_key.var
    -> is_fee_transfer:Boolean.var
    -> f:(Account.var -> (Account.var, 's) Checked.t)
    -> (var, 's) Checked.t

  val modify_account_recv :
       var
    -> Compressed_public_key.var
    -> f:(Account.var -> (Account.var, 's) Checked.t)
    -> (var, 's) Checked.t
end

module Frozen = struct
  module type S = sig
    module Ledger_hash : S

    include S

    val of_ledger_hash : Ledger_hash.t -> t
  end
end
