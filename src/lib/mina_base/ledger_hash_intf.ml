open Snark_params
open Snarky_backendless
open Step

module type S = sig
  include Ledger_hash_intf0.S

  type path = Random_oracle.Digest.t list

  type _ Request.t +=
    | Get_path : Account.Index.t -> path Request.t
    | Get_element : Account.Index.t -> (Account.t * path) Request.t
    | Set : Account.Index.t * Account.t -> unit Request.t
    | Find_index : Account_id.t -> Account.Index.t Request.t

  val get :
    depth:int -> var -> Account.Index.Unpacked.var -> Account.var Checked.t

  val merge : height:int -> t -> t -> t

  (** string representation of hash is Base58Check of bin_io representation *)
  val to_base58_check : t -> string

  val of_base58_check : string -> t Base.Or_error.t

  val empty_hash : t

  val of_digest : Random_oracle.Digest.t -> t

  val modify_account :
       depth:int
    -> var
    -> Account_id.var
    -> filter:(Account.var -> 'a Checked.t)
    -> f:('a -> Account.var -> Account.var Checked.t)
    -> var Checked.t

  val modify_account_send :
       depth:int
    -> var
    -> Account_id.var
    -> is_writeable:Boolean.var
    -> f:
         (   is_empty_and_writeable:Boolean.var
          -> Account.var
          -> Account.var Checked.t )
    -> var Checked.t

  val modify_account_recv :
       depth:int
    -> var
    -> Account_id.var
    -> f:
         (   is_empty_and_writeable:Boolean.var
          -> Account.var
          -> Account.var Checked.t )
    -> var Checked.t
end
