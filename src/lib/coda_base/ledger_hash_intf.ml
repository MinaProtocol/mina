open Import
open Snark_params
open Snarky
open Tick

module type S = sig
  include Data_hash.Full_size

  type path = Pedersen.Digest.t list

  module Tag : sig
    type t = Curr_ledger | Epoch_ledger [@@deriving eq]

    type var

    val if_ : Boolean.var -> then_:var -> else_:var -> (var, 'a) Checked.t

    val curr_ledger : var

    val epoch_ledger : var
  end

  type _ Request.t +=
    | Get_path : Tag.t * Account.Index.t -> path Request.t
    | Get_element : Tag.t * Account.Index.t -> (Account.t * path) Request.t
    | Set : Tag.t * Account.Index.t * Account.t -> unit Request.t
    | Find_index : Tag.t * Public_key.Compressed.t -> Account.Index.t Request.t

  val get :
       tag:Tag.var
    -> var
    -> Account.Index.Unpacked.var
    -> (Account.var, _) Checked.t

  val merge : height:int -> t -> t -> t

  val empty_hash : t

  val of_digest : Pedersen.Digest.t -> t

  val modify_account_send :
       tag:Tag.var
    -> var
    -> Public_key.Compressed.var
    -> is_writeable:Boolean.var
    -> f:(   is_empty_and_writeable:Boolean.var
          -> Account.var
          -> (Account.var, 's) Checked.t)
    -> (var, 's) Checked.t

  val modify_account_recv :
       tag:Tag.var
    -> var
    -> Public_key.Compressed.var
    -> f:(   is_empty_and_writeable:Boolean.var
          -> Account.var
          -> (Account.var, 's) Checked.t)
    -> (var, 's) Checked.t
end
