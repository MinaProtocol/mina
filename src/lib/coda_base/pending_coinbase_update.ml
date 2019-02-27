open Core_kernel
open Fold_lib
open Tuple_lib
open Snark_params.Tick

module type S = sig
  module Pending_coinbase : Pending_coinbase_intf.S

  module Action : sig
    type t = Added | Updated | Deleted_added | Deleted_updated
    [@@deriving eq, sexp, bin_io]

    type var

    module Checked : sig
      val added : var -> Boolean.var

      val updated : var -> Boolean.var

      val deleted_added : var -> Boolean.var

      val deleted_updated : var -> Boolean.var
    end
  end

  type ('pending_coinbase_stack, 'pending_coinbase_hash, 'action) t
  [@@deriving sexp, bin_io]

  type value = (Pending_coinbase.Stack.t, Pending_coinbase.Hash.t, Action.t) t
  [@@deriving sexp, bin_io]

  type var =
    (Pending_coinbase.Stack.var, Pending_coinbase.Hash.var, Action.var) t

  include
    Snark_params.Tick.Snarkable.S with type value := value and type var := var

  val create_value :
       prev_root:Pending_coinbase.Hash.t
    -> new_root:Pending_coinbase.Hash.t
    -> updated_stack:Pending_coinbase.Stack.t
    -> action:Action.t
    -> value

  val new_root : ('a, 'b, 'c) t -> 'b

  val prev_root : ('a, 'b, 'c) t -> 'b

  val updated_stack : ('a, 'b, 'c) t -> 'a

  val action : ('a, 'b, 'c) t -> 'c

  val genesis : value
end

module Pending_coinbase = Pending_coinbase

module Action = struct
  type t = Added | Updated | Deleted_added | Deleted_updated
  [@@deriving enum, eq, sexp, bin_io]

  let gen =
    Quickcheck.Generator.map (Int.gen_incl min max) ~f:(fun i ->
        Option.value_exn (of_enum i) )

  type var = Boolean.var * Boolean.var

  let to_bits = function
    | Added -> (false, false)
    | Updated -> (false, true)
    | Deleted_added -> (true, false)
    | Deleted_updated -> (true, true)

  let of_bits = function
    | false, false -> Added
    | false, true -> Updated
    | true, false -> Deleted_added
    | true, true -> Deleted_updated

  let%test_unit "to_bool of_bool inv" =
    let open Quickcheck in
    test (Generator.tuple2 Bool.gen Bool.gen) ~f:(fun b ->
        assert (b = to_bits (of_bits b)) )

  let typ =
    Typ.transport Typ.(Boolean.typ * Boolean.typ) ~there:to_bits ~back:of_bits

  let fold (t : t) : bool Triple.t Fold.t =
    { fold=
        (fun ~init ~f ->
          let b0, b1 = to_bits t in
          f init (b0, b1, false) ) }

  let length_in_triples = 1

  module Checked = struct
    let constant t =
      let x, y = to_bits t in
      Boolean.(var_of_value x, var_of_value y)

    let to_triples ((x, y) : var) = [(x, y, Boolean.false_)]

    let added (b0, b1) = Boolean.((not b0) && not b1)

    let updated (b0, b1) = Boolean.((not b0) && b1)

    let deleted_added (b0, b1) = Boolean.(b0 && not b1)

    let deleted_updated (b0, b1) = Boolean.(b0 && b1)

    let%test_module "predicates" =
      ( module struct
        let test_predicate checked unchecked =
          for i = min to max do
            Test_util.test_equal typ Boolean.typ checked unchecked
              (Option.value_exn (of_enum i))
          done

        let%test_unit "coinbase_stack_added" =
          test_predicate added (( = ) Added)

        let%test_unit "coinbase_stack_updated" =
          test_predicate updated (( = ) Updated)

        let%test_unit "coinbase_deleted_added" =
          test_predicate deleted_added (( = ) Deleted_added)

        let%test_unit "coinbase_deleted_updated" =
          test_predicate deleted_updated (( = ) Deleted_updated)
      end )
  end
end

type ('pending_coinbase_stack, 'pending_coinbase_hash, 'action) t_ =
  { updated_stack: 'pending_coinbase_stack
  ; prev_root: 'pending_coinbase_hash
  ; new_root: 'pending_coinbase_hash
  ; action: 'action }
[@@deriving bin_io, sexp]

type t = (Pending_coinbase.Stack.t, Pending_coinbase.Hash.t, Action.t) t_
[@@deriving bin_io, sexp]

type value = (Pending_coinbase.Stack.t, Pending_coinbase.Hash.t, Action.t) t_
[@@deriving sexp, bin_io]

type var =
  (Pending_coinbase.Stack.var, Pending_coinbase.Hash.var, Action.var) t_

let new_root t = t.new_root

let prev_root t = t.prev_root

let updated_stack t = t.updated_stack

let action t = t.action

let create_value ~prev_root ~new_root ~updated_stack ~action =
  {prev_root; new_root; updated_stack; action}

let typ : (var, t) Typ.t =
  let spec =
    Data_spec.
      [ Pending_coinbase.Stack.typ
      ; Pending_coinbase.Hash.typ
      ; Pending_coinbase.Hash.typ
      ; Action.typ ]
  in
  let of_hlist
        : 'a 'b 'c.    (unit, 'a -> 'b -> 'b -> 'c -> unit) H_list.t
          -> ('a, 'b, 'c) t_ =
    H_list.(
      fun [updated_stack; prev_root; new_root; action] ->
        {updated_stack; prev_root; new_root; action})
  in
  let to_hlist {updated_stack; prev_root; new_root; action} =
    H_list.[updated_stack; prev_root; new_root; action]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let genesis =
  { updated_stack= Pending_coinbase.Stack.empty
  ; prev_root= Pending_coinbase.Hash.empty_hash
  ; new_root= Pending_coinbase.Hash.empty_hash
  ; action= Action.Updated }
