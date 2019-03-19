(** Pending_coinbase is to keep track of all the coinbase transactions that have been applied to the ledger but for which there is no ledger proof yet. Every ledger proof corresponds to a sequence of coinbase transactions which is part of all the transactions it proves. Each of these sequences[Stack] are stored using the merkle tree representation. The stacks are operated in a FIFO manner by keeping track of its positions in the merkle tree. Whenever a ledger proof is emitted, the oldest stack is removed from the tree and when a new coinbase is applied, the latest stack is updated with the new coinbase.
The operations on the merkle tree of coinbase stacks include:
1) adding a new singleton stack
2) updating the latest stack when a new coinbase is added to it
2) deleting the oldest stack

A stack can be either be created or modified by pushing a coinbase on to it.

This module also provides an interface for the checked computations required required to prove it in snark

Stack operations are done for transaction snarks and tree operations are done for the blockchain snark*)

open Core
open Snark_params
open Snarky
open Tick
open Signature_lib
open Currency

module type S = sig
  type t [@@deriving sexp, bin_io]

  module Coinbase_data : sig
    type t = Public_key.Compressed.t * Amount.Signed.t
    [@@deriving bin_io, sexp]

    type value [@@deriving bin_io, sexp]

    type var = Public_key.Compressed.var * Amount.Signed.var

    val typ : (var, t) Typ.t

    val empty : t

    val of_coinbase : Coinbase.t -> t

    val genesis : t
  end

  module rec Hash : sig
    include Data_hash.Full_size

    val merge : height:int -> t -> t -> t

    val empty_hash : t

    val of_digest : Pedersen.Digest.t -> t
  end
  
  and Stack : sig
    include Data_hash.Full_size

    val push : t -> Coinbase.t -> t

    val empty : t

    module Checked : sig
      type t = var

      val push : t -> Coinbase_data.var -> (t, 'a) Tick.Checked.t

      val if_ : Boolean.var -> then_:t -> else_:t -> (t, _) Tick.Checked.t

      val empty : t
    end

    val hash : t -> Hash.t
  end

  val create : unit -> t Or_error.t

  val remove_coinbase_stack : t -> (Stack.t * t) Or_error.t

  val merkle_root : t -> Hash.t

  val handler : t -> is_new_stack:bool -> (request -> response) Staged.t

  val update_coinbase_stack : t -> Stack.t -> is_new_stack:bool -> t Or_error.t

  val latest_stack : t -> is_new_stack:bool -> Stack.t Or_error.t

  val oldest_stack : t -> Stack.t Or_error.t

  val hash_extra : t -> string

  module Checked : sig
    type var = Hash.var

    type path

    module Address : sig
      type value

      type var

      val typ : (var, value) Typ.t
    end

    type _ Request.t +=
      | Coinbase_stack_path : Address.value -> path Request.t
      | Get_coinbase_stack : Address.value -> (Stack.t * path) Request.t
      | Set_coinbase_stack : Address.value * Stack.t -> unit Request.t
      | Find_index_of_newest_stack : Address.value Request.t
      | Find_index_of_oldest_stack : Address.value Request.t

    val get : var -> Address.var -> (Stack.var, _) Tick.Checked.t

    val add_coinbase :
      var -> Public_key.Compressed.var * Amount.var -> (var, 's) Tick.Checked.t
    (**
   [update_stack t ~is_new_stack updtaed_stack] implements the following spec:
   - gets the address[addr] of the latest stack or a new stack
   - finds a coinbase stack in [t] at path [addr] and pushes the coinbase_data on to the stack
   - returns a root [t'] of the tree
  *)

    val pop_coinbases :
      var -> proof_emitted:Boolean.var -> (var * Stack.var, 's) Tick.Checked.t
    (**
   [pop_coinbases t pk updated_stack] implements the following spec:

   - gets the address[addr] of the oldest stack.
   - finds a coinbase stack in [t] at path [addr] and replaces it with empty stack if a [proof_emitted] is true
   - returns a root [t'] of the tree
  *)
  end
end
