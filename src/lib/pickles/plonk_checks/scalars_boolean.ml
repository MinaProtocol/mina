(* turn off fragile pattern-matching warning from sexp ppx *)
[@@@warning "-4"]


type curr_or_next = Curr | Next [@@deriving hash, eq, compare, sexp]

module Gate_type = struct
  module T = struct
    type t = Kimchi_types.gate_type =
      | Zero
      | Generic
      | Poseidon
      | CompleteAdd
      | VarBaseMul
      | EndoMul
      | EndoMulScalar
      | Lookup
      | CairoClaim
      | CairoInstruction
      | CairoFlags
      | CairoTransition
      | RangeCheck0
      | RangeCheck1
      | ForeignFieldAdd
      | ForeignFieldMul
      | Xor16
      | Rot64
    [@@deriving hash, eq, compare, sexp]
  end

  include Core_kernel.Hashable.Make (T)
  include T
end

module Lookup_pattern = struct
  module T = struct
    type t = Kimchi_types.lookup_pattern =
      | Xor
      | Lookup
      | RangeCheck
      | ForeignFieldMul
    [@@deriving hash, eq, compare, sexp]
  end

  include Core_kernel.Hashable.Make (T)
  include T
end

module Column = struct
  open Core_kernel

  module T = struct
    type t =
      | Witness of int
    [@@deriving hash, eq, compare, sexp]
  end

  include Hashable.Make (T)
  include T
end

open Column

module Env = struct
  type 'a t = {
     sub : 'a -> 'a -> 'a
    ; mul : 'a -> 'a -> 'a
 ;   var : Column.t * curr_or_next -> 'a
;    cell : 'a -> 'a
    }
end

module type S = sig
  val constant_term : 'a Env.t -> 'a

  val index_terms : 'a Env.t -> 'a Lazy.t Column.Table.t
end

(* The constraints are basically the same, but the literals in them differ. *)
module Tick : S = struct
  let constant_term (type a)
      ({ 
        sub = ( - )
       ; mul = ( * )
       ; cell;
       var
       
       } :
        a Env.t ) =
    (cell (var (Witness 0, Curr)) * cell (var (Witness 0, Curr)))
    - cell (var (Witness 0, Curr))

  let index_terms (type a) (_ : a Env.t) = Column.Table.of_alist_exn []
end

module Tock : S = struct
  let constant_term (type a)
      ({ 
        sub = ( - )
       ; mul = ( * )
       
       ; var
       ; cell
       } :
        a Env.t ) =
    (cell (var (Witness 0, Curr)) * cell (var (Witness 0, Curr)))
    - cell (var (Witness 0, Curr))

  let index_terms (type a) (_ : a Env.t) = Column.Table.of_alist_exn []
end
