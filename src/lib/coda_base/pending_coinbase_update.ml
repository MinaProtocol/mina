(** Pending coinbase update is the information required for blockchain snark computation. It consists of 
 1.Stack to be deleted [oldest_stack_after]=empty if true
 2.New or updated stack that consists of the latest coinbase
 3.Merkle root of the tree before and after peforming both update and delete*)
open Core_kernel

open Fold_lib
open Tuple_lib
open Snark_params.Tick

module type S = sig
  type ('pending_coinbase_stack, 'pending_coinbase_hash, 'bool) t
  [@@deriving sexp, bin_io]

  type value =
    (Pending_coinbase.Stack.t, Pending_coinbase.Hash.t, Boolean.value) t
  [@@deriving sexp, bin_io]

  type var =
    (Pending_coinbase.Stack.var, Pending_coinbase.Hash.var, Boolean.var) t

  include
    Snark_params.Tick.Snarkable.S with type value := value and type var := var

  val create_value :
       oldest_stack_before:Pending_coinbase.Stack.t
    -> oldest_stack_after:Pending_coinbase.Stack.t
    -> latest_stack_before:Pending_coinbase.Stack.t
    -> latest_stack_after:Pending_coinbase.Stack.t
    -> is_new_stack:bool
    -> prev_root:Pending_coinbase.Hash.t
    -> intermediate_root:Pending_coinbase.Hash.t
    -> new_root:Pending_coinbase.Hash.t
    -> value

  val new_root : ('a, 'b, 'c) t -> 'b

  val intermediate_root : ('a, 'b, 'c) t -> 'b

  val prev_root : ('a, 'b, 'c) t -> 'b

  val oldest_stack_before : ('a, 'b, 'c) t -> 'a

  val oldest_stack_after : ('a, 'b, 'c) t -> 'a

  val latest_stack_before : ('a, 'b, 'c) t -> 'a

  val latest_stack_after : ('a, 'b, 'c) t -> 'a

  val is_new_stack : ('a, 'b, 'c) t -> 'c

  val genesis : value
end

type ('pending_coinbase_stack, 'pending_coinbase_hash, 'bool) t_ =
  { oldest_stack_before: 'pending_coinbase_stack
  ; oldest_stack_after: 'pending_coinbase_stack
  ; latest_stack_before: 'pending_coinbase_stack
  ; latest_stack_after: 'pending_coinbase_stack
  ; is_new_stack: 'bool
  ; prev_root: 'pending_coinbase_hash
  ; intermediate_root: 'pending_coinbase_hash
  ; new_root: 'pending_coinbase_hash }
[@@deriving bin_io, sexp]

type t = (Pending_coinbase.Stack.t, Pending_coinbase.Hash.t, bool) t_
[@@deriving bin_io, sexp]

type value = (Pending_coinbase.Stack.t, Pending_coinbase.Hash.t, bool) t_
[@@deriving sexp, bin_io]

type var =
  (Pending_coinbase.Stack.var, Pending_coinbase.Hash.var, Boolean.var) t_

let new_root t = t.new_root

let prev_root t = t.prev_root

let create_value ~oldest_stack_before ~oldest_stack_after ~latest_stack_before
    ~latest_stack_after ~is_new_stack ~prev_root ~intermediate_root ~new_root =
  { oldest_stack_before
  ; oldest_stack_after
  ; latest_stack_before
  ; latest_stack_after
  ; is_new_stack
  ; prev_root
  ; intermediate_root
  ; new_root }

let typ : (var, t) Typ.t =
  let spec =
    Data_spec.
      [ Pending_coinbase.Stack.typ
      ; Pending_coinbase.Stack.typ
      ; Pending_coinbase.Stack.typ
      ; Pending_coinbase.Stack.typ
      ; Boolean.typ
      ; Pending_coinbase.Hash.typ
      ; Pending_coinbase.Hash.typ
      ; Pending_coinbase.Hash.typ ]
  in
  let of_hlist
        : 'a 'b 'c.    ( unit
                       , 'a -> 'a -> 'a -> 'a -> 'c -> 'b -> 'b -> 'b -> unit
                       )
                       H_list.t -> ('a, 'b, 'c) t_ =
    H_list.(
      fun [ oldest_stack_before
          ; oldest_stack_after
          ; latest_stack_before
          ; latest_stack_after
          ; is_new_stack
          ; prev_root
          ; intermediate_root
          ; new_root ] ->
        { oldest_stack_before
        ; oldest_stack_after
        ; latest_stack_before
        ; latest_stack_after
        ; is_new_stack
        ; prev_root
        ; intermediate_root
        ; new_root })
  in
  let to_hlist
      { oldest_stack_before
      ; oldest_stack_after
      ; latest_stack_before
      ; latest_stack_after
      ; is_new_stack
      ; prev_root
      ; intermediate_root
      ; new_root } =
    H_list.
      [ oldest_stack_before
      ; oldest_stack_after
      ; latest_stack_before
      ; latest_stack_after
      ; is_new_stack
      ; prev_root
      ; intermediate_root
      ; new_root ]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let genesis =
  let empty_coinbase_tree = Pending_coinbase.empty_merkle_root () in
  { oldest_stack_before= Pending_coinbase.Stack.empty
  ; oldest_stack_after= Pending_coinbase.Stack.empty
  ; latest_stack_before= Pending_coinbase.Stack.empty
  ; latest_stack_after= Pending_coinbase.Stack.empty
  ; is_new_stack= false
  ; prev_root= empty_coinbase_tree
  ; intermediate_root= empty_coinbase_tree
  ; new_root= empty_coinbase_tree }
