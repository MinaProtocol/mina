(** Pending_coinbase is to keep track of all the coinbase transactions that have been applied to the ledger but for which there is no ledger proof yet. Every ledger proof corresponds to a sequence of coinbase transactions which is part of all the transactions it proves. Each of these sequences[Stack] are stored using the merkle tree representation. The stacks are operated in a FIFO manner by keeping track of its positions[Stack_pos] in the merkle tree. Whenever a ledger proof is emitted, the oldest stack is removed from the tree and when a new coinbase is applied, the latest stack is updated with the new coinbase.
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
open Fold_lib
open Snark_bits
open Signature_lib
open Currency

module type S = sig
  type t [@@deriving sexp, bin_io]

  module Coinbase_data : sig
    type t = Public_key.Compressed.t * Amount.Signed.t [@@deriving sexp]

    type var = Public_key.Compressed.var * Amount.Signed.var
  end

  module Stack_pos : sig
    (** Used for both numbering the stacks (as keys for the sparse ledger nodes) and as address of the nodes*)
    type t

    include Bits_intf.S with type t := t

    val gen : t Quickcheck.Generator.t

    module Vector : sig
      type t = int

      val length : t

      val empty : t

      val get : t -> t -> bool

      val set : t -> t -> bool -> t
    end

    val fold_bits : t -> bool Fold.t

    val fold : t -> (bool * bool * bool) Fold.t

    module Unpacked : sig
      type value = t

      type var

      include Snarkable.S with type value := value and type var := var
    end
  end

  module rec Hash : sig
    include Data_hash.Full_size

    val merge : height:int -> t -> t -> t

    val empty_hash : t

    val of_digest : Pedersen.Digest.t -> t
  end
  
  and Stack : sig
    include Data_hash.Full_size

    val push_exn : t -> Coinbase.t -> t

    val empty : t

    module Checked : sig
      type t = var

      val push : t -> Coinbase_data.var -> (t, 'a) Tick.Checked.t

      val if_ : Boolean.var -> then_:t -> else_:t -> (t, _) Tick.Checked.t

      val empty : t
    end

    val hash : t -> Hash.t
  end

  val create_exn : unit -> t

  val remove_coinbase_stack_exn : t -> Stack.t * t

  val merkle_root : t -> Hash.t

  val empty_merkle_root : unit -> Hash.t

  val handler : t -> (request -> response) Staged.t

  val update_coinbase_stack_exn : t -> Stack.t -> is_new_stack:bool -> t

  val latest_stack_exn : t -> Stack.t option

  val oldest_stack_exn : t -> Stack.t

  module Checked : sig
    type var = Hash.var

    type path = Pedersen.Digest.t list

    type _ Request.t +=
      | Coinbase_stack_path : Stack_pos.t -> path Request.t
      | Get_coinbase_stack : Stack_pos.t -> (Stack.t * path) Request.t
      | Set_coinbase_stack : Stack_pos.t * Stack.t -> unit Request.t
      | Find_index_of_newest_stack : bool -> Stack_pos.t Request.t
      | Find_index_of_oldest_stack : Stack_pos.t Request.t

    val get : var -> Stack_pos.Unpacked.var -> (Stack.var, _) Tick.Checked.t

    val update_stack :
         var
      -> is_new_stack:Boolean.var
      -> Stack.var
      -> Stack.var
      -> (var, 's) Tick.Checked.t
    (**
   [update_stack t ~is_new_stack updtaed_stack] implements the following spec:
   - gets the address[addr] of the latest stack or a new stack if [is_new_stack] is true
   - finds a coinbase stack in [t] at path [addr] and replaces it with [updated_stack]
   - returns a root [t'] of a tree
   - resets any mutation to the store
   which is [t].
  *)

    val delete_stack :
      var -> Stack.var -> Stack.var -> (var, 's) Tick.Checked.t
    (**
   [delete_stack t pk updated_stack] implements the following spec:

   - gets the address[addr] of the oldest stack.
   - finds a coinbase stack in [t] at path [addr] and replaces it with empty stack
   - returns a root [t'] of a tree
   which is [t].
   - resets any mutation to the store
  *)
  end
end
