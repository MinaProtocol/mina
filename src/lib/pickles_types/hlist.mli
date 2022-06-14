open Poly_types

(** Basic primitives for inductive rules. In particular, heterogeneous lists
    ({!H1}, {!H2}, ...) whose length and element types are known at
    compile-time.

    To get started, read some basic usage examples in {!Hlist0.H1}, {!H1} and
    {!H1.Map}.

    {3 Implementation principle}

    In a normal value-level computation analogy:
    - modules of type {!Poly_types.T0} are values,
    - modules of types T1, T2, ... are functions taking 1, 2, ... arguments
    - functors are higher-order functions

    In the rest of this documentation, we will use the terms "type values",
    "type functions" and "higher-order type functions" w.r.t this analogy. Where
    possible, we will give for each symbol its equivalent translation at the
    value-level.

    The basic concept of this implementation of heterogeneous lists is inspired
    from Haskell's Hlist library: {: https://okmij.org/ftp/Haskell/HList-ext.pdf}
*)

(** {1 Supporting transformers} *)

(** The following modules and functors are support tools used to manipulate
    types that are then fed to the heterogeneous lists defined below (see
    {!section:lists}). *)

(** {2 Arity transformers} *)

(**
   The following higher-order functions artificially increase the number of
   arguments of a function (or value), by creating a function that ignores extra
   parameters.
*)

(** Map arity 0 to 1: [let e01 t = fun _ -> t] *)
module E01 : functor (T : T0) -> sig
  type _ t = T.t
end

(** Map arity 0 to 2: [let e02 t = fun _ _ -> t] *)
module E02 : functor (T : T0) -> sig
  type (_, _) t = T.t
end

(** Map arity 0 to 3: [let e02 t = fun _ _ _ -> t] *)
module E03 : functor (T : T0) -> sig
  type (_, _, _) t = T.t
end

(** Map arity 0 to 4: [let e02 t = fun _ _ _ _ -> t] *)
module E04 : functor (T : T0) -> sig
  type (_, _, _, _) t = T.t
end

(** Map arity 0 to 6: [let e06 t = fun _ _ _ _ _ _ -> t] *)
module E06 (T : T0) : sig
  type (_, _, _, _, _, _) t = T.t
end

(** Map arity 1 to 3: [let e13 t = fun a _ _ -> t a] *)
module E13 : functor (T : T1) -> sig
  type ('a, _, _) t = 'a T.t
end

(** Map arity 2 to 3: [let e23 t = fun a b _ -> t a b] *)
module E23 : functor (T : T2) -> sig
  type ('a, 'b, _) t = ('a, 'b) T.t
end

(** {2 Tuple transformers} *)

(**
   The following higher-order functions take multiple functions F, G, ... and
   return a function which applies all of its arguments to F, G, ... and packs
   the result in a tuple.
*)

(** Tuple of 2 function applications:
    [let tuple2 f g = fun a b c -> (f a b c, g a b c)] *)
module Tuple2 : functor (F : T3) (G : T3) -> sig
  type ('a, 'b, 'c) t = ('a, 'b, 'c) F.t * ('a, 'b, 'c) G.t
end

(** Tuple of 3 function applications:
    [let tuple3 f g h = fun a b c -> (f a b c, g a b c, h a b c)] *)
module Tuple3 : functor (F : T3) (G : T3) (H : T3) -> sig
  type ('a, 'b, 'c) t = ('a, 'b, 'c) F.t * ('a, 'b, 'c) G.t * ('a, 'b, 'c) H.t
end

(** Tuple of 4 function applications:
    [let tuple4 f g h i = fun a b c -> (f a b c, g a b c, ..., i a b c)] *)
module Tuple4 : functor (F : T3) (G : T3) (H : T3) (I : T3) -> sig
  type ('a, 'b, 'c) t =
    ('a, 'b, 'c) F.t * ('a, 'b, 'c) G.t * ('a, 'b, 'c) H.t * ('a, 'b, 'c) I.t
end

(** Tuple of 5 function applications:
    [let tuple4 f g h i = fun a b c -> (f a b c, g a b c, ..., j a b c)] *)
module Tuple5 : functor (F : T3) (G : T3) (H : T3) (I : T3) (J : T3) -> sig
  type ('a, 'b, 'c) t =
    ('a, 'b, 'c) F.t
    * ('a, 'b, 'c) G.t
    * ('a, 'b, 'c) H.t
    * ('a, 'b, 'c) I.t
    * ('a, 'b, 'c) J.t
end

(** {2 Argument selectors} *)

(** The following Functions just return one of their arguments. *)

(** Always return first argument: [let fst a _ = a] *)
module Arg1 : sig
  type ('a, _, _) t = 'a
end

(** Always return second argument: [let snd _ b = b] *)
module Arg2 : sig
  type (_, 'a, _) t = 'a
end

(** {2 Application transformers} *)

(** The following higher-order functions composes function applications in
    specific ways.
*)

(** Compose one binary function [F] and two unary functions [X] and [Y] into
    a binary function that applies [X] (resp. [Y]) to its first (resp. second)
    argument before passing both to [F]:
    [let apply2 f x y = fun a b -> f (x a) (y b)]
*)
module Apply2 : functor (F : T2) (X : T1) (Y : T1) -> sig
  type ('a, 'b) t = ('a X.t, 'b Y.t) F.t
end

(** Transforms a binary function into an unary one by duplicating its argument.
    [let dup f = fun x -> f x x]
*)
module Dup : functor (F : T2) -> sig
  type 'a t = ('a, 'a) F.t
end

(** Reification of list length with Peano integers, see {!Hlist0.Length}. *)
module Length = Hlist0.Length

(** {1:lists Heterogeneous lists} *)

(** {2 Over one type parameter} *)

(**
   The following modules are named as with the following scheme:
   - Module H[X] is the type of (and operations on) heterogeneous lists whose
     content type varies over [X] different type parameters. See {!H1} for a
     detailed example.
   - Module H[X]_[Y] is the type of (and operations on) heterogeneous lists whose
     content type varies over [X] different type parameters from cell to cell,
     but also varies from list to list over [Y] other homogeneous type
     parameters. See {!Hlist0.H1_1} for a detailed example.
*)

(** Operations on heterogeneous lists whose content type varies over a single
    type parameter. Read {!Hlist0.H1} first.

    Most operations are functors that take a module [A] as a first argument.
    This module is a type function which maps the varying type parameter to the
    actual contained type.

    In all examples below, we will assume that [A] has the following definition:
    {[module A = struct
        type 'a t = 'a option
      end
    ]}
*)
module H1 : sig
  (** Core datatype, see {!Hlist0.H1}. *)
  module T = Hlist0.H1

  (** Iterate over a heterogeneous list with a polymorphic function over the
      varying type parameter.

      The second functor parameter is a module containing that polymorphic
      function. For example, with
      {[module F = struct
          let f (x : 'a option) = assert (Option.is_some x)
        end
      ]}
      [H1.Iter.(A)(F).f l] will iterate over the list [l] and check that each
      value if the least has the form [Some y].
  *)
  module Iter : functor
    (A : T1)
    (_ : sig
       val f : 'a A.t -> unit
     end)
    -> sig
    val f : 'a T(A).t -> unit
  end

  (** Construct an heterogeneous list from an homogeneous vector, adapting the
      varying type parameter associated with the [Length.t] argument. *)
  module Of_vector : functor (X : T0) -> sig
    val f :
      ('xs, 'length) Length.t -> (X.t, 'length) Vector.t -> 'xs T(E01(X)).t
  end

  (** Map over a heterogeneous list with a polymorphic function transforming the
      underlying structure of the contained values.

      The second functor parameter defines the resulting type structure after
      the map, and the third functor parameter contains the mapping function.
      For example, with
      {[module B = struct
          type 'a t = ('a, string) result
        end
        module F = struct
          let f (x : 'a option) = match x with
            | Some v -> Ok v
            | None -> Error "was None"
        end
      ]}
      [H1.Map.(A).(B).(F).f l] will map over the list [l] transforming all
      options into results, not changing the varying type parameter.
      {[
        let l = Some 1 :: None :: Some 'a' :: Some None :: None :: [] in
        H1.Map.(A).(B).(F).f l
          = Ok 1 :: Error "was None" :: Ok 'a' :: Ok None :: Error "was None" :: []
      ]}
  *)
  module Map : functor
    (A : T1)
    (B : T1)
    (_ : sig
       val f : 'a A.t -> 'a B.t
     end)
    -> sig
    val f : 'a T(A).t -> 'a T(B).t
  end

  (** Fold over a heterogeneous list with a polymorphic function accumulating
      information on the contained values.

      The second functor parameter contains the type of the fold result, and the
      third parameter contains the folding function.
      For example, with
      {[module X = struct
          type t = int
        end
        module F = struct
          let f (acc : int) (x : 'a option) = match x with
            | Some _ -> acc + 1
            | None -> acc
        end
      ]}
      [H1.Fold.(A).(X).(F).f l] will fold over the list [l] and return the
      number of cells that contain some value.
  *)
  module Fold : functor
    (A : T1)
    (X : T0)
    (_ : sig
       val f : X.t -> 'a A.t -> X.t
     end)
    -> sig
    val f : init:X.t -> 'a T(A).t -> X.t
  end

  (** Map then reduce over a heterogeneous list, given a polymorphic map function
      and a monomorphic reduce function.

      The second functor parameter contains the type of the reduce result, and
      the third functor parameter contains both the map and reduce functions.

      The behaviour can be seen as a composition of {!Map} and {!Fold}.
  *)
  module Map_reduce : functor
    (A : T1)
    (X : T0)
    (_ : sig
       val reduce : X.t -> X.t -> X.t

       val map : 'a A.t -> X.t
     end)
    -> sig
    val f : 'a T(A).t -> X.t
  end

  (** Converting the heterogeneous list to a homogeneous vector. This is only
      possible when the contained types do not use the varying type parameter
      (see {!E01}). This is enforced by the type system.
  *)
  module To_vector : functor (X : T0) -> sig
    val f :
      ('xs, 'length) Length.t -> 'xs T(E01(X)).t -> (X.t, 'length) Vector.t
  end

  (** Data type of a heterogeneous list of pairs.
   
      Both sides of the tuple are heterogeneous over the same type parameter. The
      underlying type structures are determined by the type functions in the
      first and second functor parameters.
  *)
  module Tuple2 : functor (A : T1) (B : T1) -> sig
    type 'a t = 'a A.t * 'a B.t
  end

  (** Usual zipping operation over two heterogeneous lists. 
  
      The two functor parameters define the underlying contained type structures
      of the two lists.

      The varying type parameter must match cell-wise between the two lists.
      This is ensured by the type system (this also ensures the their lengths
      are the same).
  *)
  module Zip : functor (A : T1) (B : T1) -> sig
    val f : 'a T(A).t -> 'a T(B).t -> 'a T(Tuple2(A)(B)).t
  end

  (** Build a function that can transform a heterogeneous list into a
      {!Snarky_backendless.Typ.t} from a function that does the same for one
      element. See {!Snarky_backendless.Typ} and its documentation for more
      information.
  *)
  module Typ : functor
    (Impl : sig
       type field
     end)
    (A : T1)
    (Var : T1)
    (Val : T1)
    (_ : sig
       val f :
         'a A.t -> ('a Var.t, 'a Val.t, Impl.field) Snarky_backendless.Typ.t
     end)
    -> sig
    val f :
         'xs T(A).t
      -> ('xs T(Var).t, 'xs T(Val).t, Impl.field) Snarky_backendless.Typ.t
  end
end

(** Identity type function, see {!Hlist0.Id}. *)
module Id = Hlist0.Id

(** Simplest heterogeneous list, see {!Hlist0.HlistId}. *)
module HlistId = Hlist0.HlistId

(** {2 Over two type parameters} *)

(** Operations on heterogeneous lists whose content type varies over a two
    type parameters.

    Similar to {!H1}, with less operations.
*)
module H2 : sig
  (* Base datatype, see {!H1.T} and {!Hlist0.H1}. *)
  module T : functor (A : T2) -> sig
    type (_, _) t =
      | [] : (unit, unit) t
      | ( :: ) : ('a1, 'a2) A.t * ('b1, 'b2) t -> ('a1 * 'b1, 'a2 * 'b2) t

    val length : ('tail1, 'tail2) t -> 'tail1 Length.n
  end

  (** Simple type function, see {!Arg1}. Can be used to use a [H2] like a
      {!Hlist0.HlistId}. *)
  module Arg1 : sig
    type ('a, _) t = 'a
  end

  (** See {!H1.Tuple2}. *)
  module Tuple2 : functor (A : T2) (B : T2) -> sig
    type ('a, 'b) t = ('a, 'b) A.t * ('a, 'b) B.t
  end

  (** See {!H1.Zip}. *)
  module Zip : functor (A : T2) (B : T2) -> sig
    val f : ('a, 'b) T(A).t -> ('a, 'b) T(B).t -> ('a, 'b) T(Tuple2(A)(B)).t
  end

  (** See {!H1.Map}. *)
  module Map : functor
    (A : T2)
    (B : T2)
    (_ : sig
       val f : ('a, 'b) A.t -> ('a, 'b) B.t
     end)
    -> sig
    val f : ('a, 'b) T(A).t -> ('a, 'b) T(B).t
  end

  (** See {!H1.Typ}. *)
  module Typ : functor
    (Impl : sig
       type field

       module Typ : sig
         type ('var, 'value) t = ('var, 'value, field) Snarky_backendless.Typ.t
       end
     end)
    -> sig
    val f :
         ('vars, 'values) T(Impl.Typ).t
      -> ( 'vars H1.T(Id).t
         , 'values H1.T(Id).t
         , Impl.field )
         Snarky_backendless.Typ.t
  end
end

(** Data type of heterogeneous lists whose content type varies over two type
    parameters, but also varies homogeneously over one other type parameter.
    It supports operations similar to {!H1}. See also {!Hlist0.H1_1}.
*)
module H2_1 : sig
  (** Core data type. *)
  module T : functor
    (A : sig
       type (_, _, _) t
     end)
    -> sig
    type (_, _, 's) t =
      | [] : (unit, unit, 'a) t
      | ( :: ) :
          ('a1, 'a2, 's) A.t * ('b1, 'b2, 's) t
          -> ('a1 * 'b1, 'a2 * 'b2, 's) t

    val length : ('tail1, 'tail2, 'e) t -> 'tail1 Length.n
  end

  (** See {!H1.Iter}. *)
  module Iter : functor
    (A : T3)
    (_ : sig
       val f : ('a, 'b, 'c) A.t -> unit
     end)
    -> sig
    val f : ('a, 'b, 'c) T(A).t -> unit
  end

  (** See {!H1.Map}. *)
  module Map : functor
    (A : T3)
    (B : T3)
    (_ : sig
       val f : ('a, 'b, 'c) A.t -> ('a, 'b, 'c) B.t
     end)
    -> sig
    val f : ('a, 'b, 'c) T(A).t -> ('a, 'b, 'c) T(B).t
  end

  (** Similar to {!H1.Map}, but only works on lists of which the homogeneous type
      parameter is [Env.t] (the third functor parameter). *)
  module Map_ : functor
    (A : T3)
    (B : T3)
    (Env : sig
       type t
     end)
    (_ : sig
       val f : ('a, 'b, Env.t) A.t -> ('a, 'b, Env.t) B.t
     end)
    -> sig
    val f : ('a, 'b, Env.t) T(A).t -> ('a, 'b, Env.t) T(B).t
  end

  (** See {!H1.Zip}. *)
  module Zip : functor (A : T3) (B : T3) -> sig
    val f :
         ('a, 'b, 'c) T(A).t
      -> ('a, 'b, 'c) T(B).t
      -> ('a, 'b, 'c) T(Tuple2(A)(B)).t
  end

  (** Similar to {!Zip}, but zips 3 lists into a list of triples. *)
  module Zip3 : functor (A : T3) (B : T3) (C : T3) -> sig
    val f :
         ('a, 'b, 'c) T(A).t
      -> ('a, 'b, 'c) T(B).t
      -> ('a, 'b, 'c) T(C).t
      -> ('a, 'b, 'c) T(Tuple3(A)(B)(C)).t
  end

  (** Reverse operation of {!Zip3}. Only works on a list of triplee, which is
      ensured by the type system. *)
  module Unzip3 : functor (A : T3) (B : T3) (C : T3) -> sig
    val f :
         ('a, 'b, 'c) T(Tuple3(A)(B)(C)).t
      -> ('a, 'b, 'c) T(A).t * ('a, 'b, 'c) T(B).t * ('a, 'b, 'c) T(C).t
  end

  (** Similar to {!Zip}, but zips 3 lists into a list of quadruples. *)
  module Zip4 : functor (A : T3) (B : T3) (C : T3) (D : T3) -> sig
    val f :
         ('a, 'b, 'c) T(A).t
      -> ('a, 'b, 'c) T(B).t
      -> ('a, 'b, 'c) T(C).t
      -> ('a, 'b, 'c) T(D).t
      -> ('a, 'b, 'c) T(Tuple4(A)(B)(C)(D)).t
  end

  (** Similar to {!Zip}, but zips 3 lists into a list of quintuples. *)
  module Zip5 : functor (A : T3) (B : T3) (C : T3) (D : T3) (E : T3) -> sig
    val f :
         ('a, 'b, 'c) T(A).t
      -> ('a, 'b, 'c) T(B).t
      -> ('a, 'b, 'c) T(C).t
      -> ('a, 'b, 'c) T(D).t
      -> ('a, 'b, 'c) T(E).t
      -> ('a, 'b, 'c) T(Tuple5(A)(B)(C)(D)(E)).t
  end

  (** See {!H1.Of_vector}. *)
  module Of_vector : functor (X : T0) -> sig
    val f :
         ('xs, 'length) Length.t
      -> ('ys, 'length) Length.t
      -> (X.t, 'length) Vector.t
      -> ('xs, 'ys, 'e) T(E03(X)).t
  end

  (** See {!H1.To_vector}. *)
  module To_vector : functor (X : T0) -> sig
    val f :
         ('xs, 'length) Length.t
      -> ('xs, 'ys, 'e) T(E03(X)).t
      -> (X.t, 'length) Vector.t
  end
end

(** {2 Over three type parameters} *)

(** Operations on heterogeneous lists whose content type varies over a tree 
    type parameters.

    Similar to {!H1}, with less operations.
*)
module H3 : sig
  (** Core data type. *)
  module T : functor
    (A : sig
       type (_, _, _) t
     end)
    -> sig
    type (_, _, _) t =
      | [] : (unit, unit, unit) t
      | ( :: ) :
          ('a1, 'a2, 'a3) A.t * ('b1, 'b2, 'b3) t
          -> ('a1 * 'b1, 'a2 * 'b2, 'a3 * 'b3) t

    val length : ('tail1, 'tail2, 'tail3) t -> 'tail1 Length.n
  end

  (** See {!H1.To_vector}. *)
  module To_vector : functor (X : T0) -> sig
    val f :
         ('a, 'length) Length.t
      -> ('a, 'b, 'c) T(E03(X)).t
      -> (X.t, 'length) Vector.t
  end

  (** See {!H1.Zip}. *)
  module Zip : functor (A : T3) (B : T3) -> sig
    val f :
         ('a, 'b, 'c) T(A).t
      -> ('a, 'b, 'c) T(B).t
      -> ('a, 'b, 'c) T(Tuple2(A)(B)).t
  end

  (** See {!H2.Arg1}. *)
  module Arg1 : sig
    type ('a, _, _) t = 'a
  end

  (** Build a function that transforms a {!H3} into a {!H1} by retaining only the
      first type parameter. The underlying type structures of the input and output
      lists are determined by the first two functor parameters. The third must
      contain a function that map a ternary type to an unary one.
  *)
  module Map1_to_H1 : functor
    (A : T3)
    (B : T1)
    (_ : sig
       val f : ('a, 'b, 'c) A.t -> 'a B.t
     end)
    -> sig
    val f : ('a, 'b, 'c) T(A).t -> 'a H1.T(B).t
  end

  (** Similar to {!Map1_to_H1}, except we only keep the second type parameter
      instead of the first. *)
  module Map2_to_H1 : functor
    (A : T3)
    (B : T1)
    (_ : sig
       val f : ('a, 'b, 'c) A.t -> 'b B.t
     end)
    -> sig
    val f : ('a, 'b, 'c) T(A).t -> 'b H1.T(B).t
  end

  (** See {!H1.Map}. *)
  module Map : functor
    (A : T3)
    (B : T3)
    (_ : sig
       val f : ('a, 'b, 'c) A.t -> ('a, 'b, 'c) B.t
     end)
    -> sig
    val f : ('a, 'b, 'c) T(A).t -> ('a, 'b, 'c) T(B).t
  end
end

(** Data type of heterogeneous lists whose content type varies over three type
    parameters, but also varies homogeneously over one other type parameters.
    It supports no operations. See {!Hlist0.H1_1}.
*)
module H3_1 : functor
  (A : sig
     type (_, _, _, _) t
   end)
  -> sig
  type (_, _, _, 's) t =
    | [] : (unit, unit, unit, 'a) t
    | ( :: ) :
        ('a1, 'a2, 'a3, 's) A.t * ('b1, 'b2, 'b3, 's) t
        -> ('a1 * 'b1, 'a2 * 'b2, 'a3 * 'b3, 's) t

  val length : ('tail1, 'tail2, 'tail3, 'e) t -> 'tail1 Length.n
end

(** Data type of heterogeneous lists whose content type varies over three type
    parameters, but also varies homogeneously over two other type parameters.
    It supports no operations.
    See {!Hlist0.H1_1}.
*)
module H3_2 : sig
  module T : functor
    (A : sig
       type (_, _, _, _, _) t
     end)
    -> sig
    type (_, _, _, 's1, 's2) t =
      | [] : (unit, unit, unit, 'a, 'b) t
      | ( :: ) :
          ('a1, 'a2, 'a3, 's1, 's2) A.t * ('b1, 'b2, 'b3, 's1, 's2) t
          -> ('a1 * 'b1, 'a2 * 'b2, 'a3 * 'b3, 's1, 's2) t

    val length : ('t1, 't2, 't3, 'e1, 'e2) t -> 't1 Length.n
  end
end

(** Data type of heterogeneous lists whose content type varies over three type
    parameters, but also varies homogeneously over three other type parameters.
    It supports no operations.
    See {!Hlist0.H1_1}.
*)
module H3_3 : sig
  module T : functor
    (A : sig
       type (_, _, _, _, _, _) t
     end)
    -> sig
    type (_, _, _, 's1, 's2, 's3) t =
      | [] : (unit, unit, unit, 'a, 'b, 'c) t
      | ( :: ) :
          ('a1, 'a2, 'a3, 's1, 's2, 's3) A.t * ('b1, 'b2, 'b3, 's1, 's2, 's3) t
          -> ('a1 * 'b1, 'a2 * 'b2, 'a3 * 'b3, 's1, 's2, 's3) t

    val length : ('t1, 't2, 't3, 'e1, 'e2, 'e3) t -> 't1 Length.n
  end
end

(** Data type of heterogeneous lists whose content type varies over three type
    parameters, but also varies homogeneously over four other type parameters.
    It supports no operations.
    See {!Hlist0.H1_1}.
*)
module H3_4 : sig
  module T : functor
    (A : sig
       type (_, _, _, _, _, _, _) t
     end)
    -> sig
    type (_, _, _, 's1, 's2, 's3, 's4) t =
      | [] : (unit, unit, unit, 'a, 'b, 'c, 'd) t
      | ( :: ) :
          ('a1, 'a2, 'a3, 's1, 's2, 's3, 's4) A.t
          * ('b1, 'b2, 'b3, 's1, 's2, 's3, 's4) t
          -> ('a1 * 'b1, 'a2 * 'b2, 'a3 * 'b3, 's1, 's2, 's3, 's4) t

    val length : ('t1, 't2, 't3, 'e1, 'e2, 'e3, 'e4) t -> 't1 Length.n
  end
end

(** {2 Over four type parameters} *)

(** Operations on heterogeneous lists whose content type varies over a four
    type parameters.

    Similar to {!H1}.
*)
module H4 : sig
  (** Core data type. *)
  module T : functor
    (A : sig
       type (_, _, _, _) t
     end)
    -> sig
    type (_, _, _, _) t =
      | [] : (unit, unit, unit, unit) t
      | ( :: ) :
          ('a1, 'a2, 'a3, 'a4) A.t * ('b1, 'b2, 'b3, 'b4) t
          -> ('a1 * 'b1, 'a2 * 'b2, 'a3 * 'b3, 'a4 * 'b4) t

    val length : ('tail1, 'tail2, 'tail3, 'tail4) t -> 'tail1 Length.n
  end

  (** See {!H1.Fold}. *)
  module Fold : functor
    (A : T4)
    (X : T0)
    (_ : sig
       val f : X.t -> ('a, 'b, 'c, 'd) A.t -> X.t
     end)
    -> sig
    val f : init:X.t -> ('a, 'b, 'c, 'd) T(A).t -> X.t
  end

  (** See {!H1.Iter}. *)
  module Iter : functor
    (A : T4)
    (_ : sig
       val f : ('a, 'b, 'c, 'd) A.t -> unit
     end)
    -> sig
    val f : ('a, 'b, 'c, 'd) T(A).t -> unit
  end

  (** See {!H1.Map}. *)
  module Map : functor
    (A : T4)
    (B : T4)
    (_ : sig
       val f : ('a, 'b, 'c, 'd) A.t -> ('a, 'b, 'c, 'd) B.t
     end)
    -> sig
    val f : ('a, 'b, 'c, 'd) T(A).t -> ('a, 'b, 'c, 'd) T(B).t
  end

  (** See {!H1.To_vector}. *)
  module To_vector : functor (X : T0) -> sig
    val f :
         ('a, 'length) Length.t
      -> ('a, 'b, 'c, 'd) T(E04(X)).t
      -> (X.t, 'length) Vector.t
  end

  (** See {!H1.Tuple2}. *)
  module Tuple2 : functor (A : T4) (B : T4) -> sig
    type ('a, 'b, 'c, 'd) t = ('a, 'b, 'c, 'd) A.t * ('a, 'b, 'c, 'd) B.t
  end

  (** See {!H1.Zip}. *)
  module Zip : functor (A : T4) (B : T4) -> sig
    val f :
         ('a, 'b, 'c, 'd) T(A).t
      -> ('a, 'b, 'c, 'd) T(B).t
      -> ('a, 'b, 'c, 'd) T(Tuple2(A)(B)).t
  end

  (** Convert a length counting on the first type parameter of a list into the
      same length counting on the second type parameter of the list. *)
  module Length_1_to_2 : functor (A : T4) -> sig
    val f :
      ('xs, 'ys, 'a, 'b) T(A).t -> ('xs, 'n) Length.t -> ('ys, 'n) Length.t
  end

  (** See {!H1.Typ}. *)
  module Typ : functor
    (Impl : sig
       type field
     end)
    (A : T4)
    (Var : T3)
    (Val : T3)
    (_ : sig
       val f :
            ('var, 'value, 'n1, 'n2) A.t
         -> ( ('var, 'n1, 'n2) Var.t
            , ('value, 'n1, 'n2) Val.t
            , Impl.field )
            Snarky_backendless.Typ.t
     end)
    -> sig
    val transport :
         ('a, 'b, 'c) Snarky_backendless.Typ.t
      -> there:('d -> 'b)
      -> back:('b -> 'd)
      -> ('a, 'd, 'c) Snarky_backendless.Typ.t

    val transport_var :
         ('a, 'b, 'c) Snarky_backendless.Typ.t
      -> there:('d -> 'a)
      -> back:('a -> 'd)
      -> ('d, 'b, 'c) Snarky_backendless.Typ.t

    val tuple2 :
         ('a, 'b, 'c) Snarky_backendless.Typ.t
      -> ('d, 'e, 'c) Snarky_backendless.Typ.t
      -> ('a * 'd, 'b * 'e, 'c) Snarky_backendless.Typ.t

    val unit : unit -> (unit, unit, 'a) Snarky_backendless.Typ.t

    val f :
         ('vars, 'values, 'ns1, 'ns2) T(A).t
      -> ( ('vars, 'ns1, 'ns2) H3.T(Var).t
         , ('values, 'ns1, 'ns2) H3.T(Val).t
         , Impl.field )
         Snarky_backendless.Typ.t
  end
end

(** Operations on heterogeneous lists whose content type varies over a four
    type parameters.

    Similar to {!H1}.
*)
module H6 : sig
  (** Core data type. *)
  module T : functor
    (A : sig
       type (_, _, _, _, _, _) t
     end)
    -> sig
    type (_, _, _, _, _, _) t =
      | [] : (unit, unit, unit, unit, unit, unit) t
      | ( :: ) :
          ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) A.t * ('b1, 'b2, 'b3, 'b4, 'b5, 'b6) t
          -> ( 'a1 * 'b1
             , 'a2 * 'b2
             , 'a3 * 'b3
             , 'a4 * 'b4
             , 'a5 * 'b5
             , 'a6 * 'b6 )
             t

    val length :
      ('tail1, 'tail2, 'tail3, 'tail4, 'tail5, 'tail6) t -> 'tail1 Length.n
  end

  (** See {!H1.Fold}. *)
  module Fold : functor
    (A : T6)
    (X : T0)
    (_ : sig
       val f : X.t -> ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) A.t -> X.t
     end)
    -> sig
    val f : init:X.t -> ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) T(A).t -> X.t
  end

  (** See {!H1.Iter}. *)
  module Iter : functor
    (A : T6)
    (_ : sig
       val f : ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) A.t -> unit
     end)
    -> sig
    val f : ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) T(A).t -> unit
  end

  (** See {!H1.Map}. *)
  module Map : functor
    (A : T6)
    (B : T6)
    (_ : sig
       val f :
            ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) A.t
         -> ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) B.t
     end)
    -> sig
    val f :
         ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) T(A).t
      -> ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) T(B).t
  end

  (** See {!H1.To_vector}. *)
  module To_vector : functor (X : T0) -> sig
    val f :
         ('a1, 'length) Length.t
      -> ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) T(E06(X)).t
      -> (X.t, 'length) Vector.t
  end

  (** See {!H1.Tuple2}. *)
  module Tuple2 : functor (A : T6) (B : T6) -> sig
    type ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) t =
      ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) A.t * ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) B.t
  end

  (** See {!H1.Zip}. *)
  module Zip : functor (A : T6) (B : T6) -> sig
    val f :
         ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) T(A).t
      -> ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) T(B).t
      -> ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) T(Tuple2(A)(B)).t
  end

  (** Convert a length counting on the first type parameter of a list into the
      same length counting on the second type parameter of the list. *)
  module Length_1_to_2 : functor (A : T6) -> sig
    val f :
         ('a1, 'a2, 'a3, 'a4, 'a5, 'a6) T(A).t
      -> ('a1, 'n) Length.t
      -> ('a2, 'n) Length.t
  end

  (** See {!H1.Typ}. *)
  module Typ : functor
    (Impl : sig
       type field
     end)
    (A : T6)
    (Var : T4)
    (Val : T4)
    (_ : sig
       val f :
            ('var, 'value, 'ret_var, 'ret_value, 'n1, 'n2) A.t
         -> ( ('var, 'ret_var, 'n1, 'n2) Var.t
            , ('value, 'ret_value, 'n1, 'n2) Val.t
            , Impl.field )
            Snarky_backendless.Typ.t
     end)
    -> sig
    val transport :
         ('a, 'b, 'c) Snarky_backendless.Typ.t
      -> there:('d -> 'b)
      -> back:('b -> 'd)
      -> ('a, 'd, 'c) Snarky_backendless.Typ.t

    val transport_var :
         ('a, 'b, 'c) Snarky_backendless.Typ.t
      -> there:('d -> 'a)
      -> back:('a -> 'd)
      -> ('d, 'b, 'c) Snarky_backendless.Typ.t

    val tuple2 :
         ('a, 'b, 'c) Snarky_backendless.Typ.t
      -> ('d, 'e, 'c) Snarky_backendless.Typ.t
      -> ('a * 'd, 'b * 'e, 'c) Snarky_backendless.Typ.t

    val unit : unit -> (unit, unit, 'a) Snarky_backendless.Typ.t

    val f :
         ('vars, 'values, 'ret_vars, 'ret_values, 'ns1, 'ns2) T(A).t
      -> ( ('vars, 'ret_vars, 'ns1, 'ns2) H4.T(Var).t
         , ('values, 'ret_values, 'ns1, 'ns2) H4.T(Val).t
         , Impl.field )
         Snarky_backendless.Typ.t
  end
end

(** Data type of heterogeneous lists whose content type varies over four type
    parameters, but also varies homogeneously over two other type parameters.
    It supports no operations. See {!Hlist0.H1_1}.
*)
module H4_2 : sig
  module T : functor
    (A : sig
       type (_, _, _, _, _, _) t
     end)
    -> sig
    type (_, _, _, _, 's1, 's2) t =
      | [] : (unit, unit, unit, unit, 'a, 'b) t
      | ( :: ) :
          ('a1, 'a2, 'a3, 'a4, 's1, 's2) A.t * ('b1, 'b2, 'b3, 'b4, 's1, 's2) t
          -> ('a1 * 'b1, 'a2 * 'b2, 'a3 * 'b3, 'a4 * 'b4, 's1, 's2) t

    val length : ('t1, 't2, 't3, 't4, 'e1, 'e2) t -> 't1 Length.n
  end
end

(** Data type of heterogeneous lists whose content type varies over four type
    parameters, but also varies homogeneously over two other type parameters.
    It supports no operations. See {!Hlist0.H1_1}.
*)
module H6_2 : sig
  module T : functor
    (A : sig
       type (_, _, _, _, _, _, _, _) t
     end)
    -> sig
    type (_, _, _, _, _, _, 's1, 's2) t =
      | [] : (unit, unit, unit, unit, unit, unit, 'a, 'b) t
      | ( :: ) :
          ('a1, 'a2, 'a3, 'a4, 'a5, 'a6, 's1, 's2) A.t
          * ('b1, 'b2, 'b3, 'b4, 'b5, 'b6, 's1, 's2) t
          -> ( 'a1 * 'b1
             , 'a2 * 'b2
             , 'a3 * 'b3
             , 'a4 * 'b4
             , 'a5 * 'b5
             , 'a6 * 'b6
             , 's1
             , 's2 )
             t

    val length : ('t1, 't2, 't3, 't4, 't5, 't6, 'e1, 'e2) t -> 't1 Length.n
  end
end

(** {2 Maximum functions for natural integer lists} *)

(** Utilities to compute the maximum of heterogeneous lists containing natural
    integers whose type represent their value (hence the need for heterogeneous
    lists). *)

(** Type of modules returned by {!max} and {!max_exn}. Contains the maximum
    value [n] and the list of its predecessors [p]. *)
module type Max_s = sig
  (** Type of the list. *)
  type ns

  (** Type-encoded maximum. *)
  type n

  (** Maximum value. *)
  val n : n Nat.t

  (** The other values, inferior to the maximum. See {!Hlist0.H1_1} and {!Nat}. *)
  val p : (ns, n) Hlist0.H1_1(Nat.Lte).t
end

(** Type of the maximum for heterogeneous lists containing types ['ns]. *)
type 'ns max = (module Max_s with type ns = 'ns)

(** Find the maximum of a non-empty (ensured by the type system)
    list of naturals. *)
val max : ('n * 'ns) H1.T(Nat).t -> ('n * 'ns) max

(** Find the maximum of a list of naturals, raising an exception
    if it is empty. *)
val max_exn : 'ns H1.T(Nat).t -> 'ns max

(** Build the (heterogeneous) list of maximums from a vector of vectors of
    integers. See {!Vector}. *)
module Maxes : sig
  (** Module type returned by the max function [m] *)
  module type S = sig
    (** All the maxes values, as types. *)
    type ns

    (** The length of the list of maxes. *)
    type length

    (** The length of the list of maxes, reified. *)
    val length : (ns, length) Length.t

    (** The actual list of maxes. See {!H1} and {!Nat}. *)
    val maxes : ns H1.T(Nat).t
  end

  (** Transform a vector of vector of ints into a heterogeneous list of their
      maximums. Return the result packed in a {!S} module. *)
  val m :
       ((int, 'a) Vector.t, 'length) Vector.t
    -> (module S with type length = 'length)
end

(** {2 Misc. operations} *)

(** Build a function which transforms a {!Hlist0.H1_1} list into another
    {!Hlist0.H1_1} which has the same varying type parameter but a different
    homogeneous type parameter.

    The underlying contained type structures are defined by the first two
    functor parameters, and the third parameter contains a function which maps
    values between the two.
*)
module Map_1_specific : functor
  (A : T2)
  (B : T2)
  (C : sig
     type b1

     type b2

     val f : ('a, b1) A.t -> ('a, b2) B.t
   end)
  -> sig
  val f : ('a, C.b1) Hlist0.H1_1(A).t -> ('a, C.b2) Hlist0.H1_1(B).t
end

(** Handles the conversion from a list of {!Length} to its equivalent list of
    natural integers. *)
module Lengths : sig
  (** The conversion function. *)
  val extract :
    ('prev_varss, 'ns, 'env) H2_1.T(E23(Length)).t -> 'ns H1.T(Nat).t

  type ('prev_varss, 'prev_valss, 'env) t =
    | T :
        ('prev_varss, 'ns, 'env) H2_1.T(E23(Length)).t
        -> ('prev_varss, 'prev_valss, 'env) t
end
