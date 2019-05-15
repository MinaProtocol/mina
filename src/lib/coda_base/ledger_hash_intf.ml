open Import
open Snark_params
open Snarky
open Tick

module type S = sig
  include Data_hash.Full_size

  type path = Pedersen.Digest.t list

  module Tag : sig
    type t = Curr_ledger | Epoch_ledger

    module Checked : sig
      type var

      val if_ : Boolean.var -> then_:var -> else_:var -> (var, 'a) Checked.t
    end

    val curr_ledger : Checked.var

    val epoch_ledger : Checked.var
  end

  type _ Request.t +=
    | Get_path : Account.Index.t -> path Request.t
    | Get_element : Tag.t * Account.Index.t -> (Account.t * path) Request.t
    | Set : Account.Index.t * Account.t -> unit Request.t
    | Find_index : Public_key.Compressed.t -> Account.Index.t Request.t

  val get : var -> Account.Index.Unpacked.var -> (Account.var, _) Checked.t

  val merge : height:int -> t -> t -> t

  val empty_hash : t

  val of_digest : Pedersen.Digest.t -> t

  val modify_account_send :
       var
    -> Public_key.Compressed.var
    -> is_writeable:Boolean.var
    -> f:(   is_empty_and_writeable:Boolean.var
          -> Account.var
          -> (Account.var, 's) Checked.t)
    -> (var, 's) Checked.t

  val modify_account_recv :
       var
    -> Public_key.Compressed.var
    -> f:(   is_empty_and_writeable:Boolean.var
          -> Account.var
          -> (Account.var, 's) Checked.t)
    -> tag:Tag.Checked.var
    -> (var * Account.var, 's) Checked.t
end
