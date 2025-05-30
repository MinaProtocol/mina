(** Typed size vectors for Pickles. The size of the vector is encoded at the
    type level.
    The module also provides common methods available for built-in lists ['a
    list] like [map], [iter], etc.
*)

(** {1 Types} *)

(** Encode a vector at the type level with its size *)
module T : sig
  type ('a, 'b) t = ('a, 'b) Mina_wire_types.Pickles_types.Vector.t =
    | [] : ('a, Nat.z) t
    | ( :: ) : 'a * ('a, 'n) t -> ('a, 'n Nat.s) t
end

type ('a, 'b) t = ('a, 'b) T.t =
  | [] : ('a, Nat.z) t
  | ( :: ) : 'a * ('a, 'n) t -> ('a, 'n Nat.s) t

(** Simple alias for the type [t] *)
type ('a, 'n) vec = ('a, 'n) t

(** A value of type ['a e] forgets the size of the vector and contains only the
    elements of the list. It can be seen as an alias to ['a list] *)
type _ e = T : ('a, 'n) t -> 'a e

(** ['a L.t] is nothing more than an alias to ['a list]. No type level encoding
    of the size is provided. It only transports the runtime data. *)
module L : sig
  type 'a t = 'a list [@@deriving yojson]
end

(** {1 Modules} *)

(** {2 Module types} *)

module type S = sig
  type 'a t [@@deriving compare, yojson, sexp, hash, equal]

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val of_list_exn : 'a list -> 'a t

  val to_list : 'a t -> 'a list
end

(** Main module type to encode a typed size vector *)
module type VECTOR = sig
  type 'a t

  include S with type 'a t := 'a t

  module Stable : sig
    module V1 : sig
      include S with type 'a t = 'a t

      include Sigs.Binable.S1 with type 'a t = 'a t

      include Sigs.VERSIONED
    end
  end
end

module With_version (N : Nat.Intf) : sig
  module type S = sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type 'a t = ('a, N.n) vec
        [@@deriving compare, yojson, sexp, hash, equal]
      end
    end]

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val of_list_exn : 'a list -> 'a t

    val to_list : 'a t -> 'a list
  end
end

(** {2 Vectors} *)

(** Vector of size 32 *)
module Vector_32 : VECTOR with type 'a t = ('a, Nat.N32.n) vec

(** Vector of size 15 *)
module Vector_15 : VECTOR with type 'a t = ('a, Nat.N15.n) vec

(** Vector of size 16 *)
module Vector_16 : VECTOR with type 'a t = ('a, Nat.N16.n) vec

(** Vector of size 8 *)
module Vector_8 : VECTOR with type 'a t = ('a, Nat.N8.n) vec

(** Vector of size 7 *)
module Vector_7 : VECTOR with type 'a t = ('a, Nat.N7.n) vec

(** Vector of size 6 *)
module Vector_6 : VECTOR with type 'a t = ('a, Nat.N6.n) vec

(** Vector of size 5 *)
module Vector_5 : VECTOR with type 'a t = ('a, Nat.N5.n) vec

(** Vector of size 4 *)
module Vector_4 : VECTOR with type 'a t = ('a, Nat.N4.n) vec

(** Vector of size 2 *)
module Vector_2 : VECTOR with type 'a t = ('a, Nat.N2.n) vec

(** Functor to build any vector of size [N]. The parameters of the functor is a
    natural encoded at the type level. For instance, {!Vector_2} could be seen
    as the output of [With_length (Nat.N2)]
*)
module With_length (N : Nat.Intf) : S with type 'a t = ('a, N.n) vec

(** {1 Snarky related functions } *)

module Make_typ (Impl : Snarky_backendless.Snark_intf.Run) : sig
  (** [typ v t_n] creates a snarky [Typ.t] for a vector of the length [t_n] and
    sets the contents of each cell to [v] *)
  val typ :
    ('a, 'b) Impl.Typ.t -> 'd Nat.nat -> (('a, 'd) vec, ('b, 'd) vec) Impl.Typ.t

  (** Builds a Snarky type from a type [('a, 'n) t]*)
  val typ' :
       (('var, 'value) Impl.Typ.t, 'n) t
    -> (('var, 'n) t, ('value, 'n) t) Impl.Typ.t
end

(** [typ v t_n] creates a snarky [Typ.t] for a vector of the length [t_n] and
    sets the contents of each cell to [v] *)
val typ :
     ('a, 'b) Kimchi_pasta_snarky_backend.Step_impl.Typ.t
  -> 'd Nat.nat
  -> (('a, 'd) vec, ('b, 'd) vec) Kimchi_pasta_snarky_backend.Step_impl.Typ.t

(** Builds a Snarky type from a type [('a, 'n) t]*)
val typ' :
     (('var, 'value) Kimchi_pasta_snarky_backend.Step_impl.Typ.t, 'n) t
  -> (('var, 'n) t, ('value, 'n) t) Kimchi_pasta_snarky_backend.Step_impl.Typ.t

(** [wrap_typ v t_n] creates a snarky [Typ.t] for a vector of the length [t_n] and
    sets the contents of each cell to [v] *)
val wrap_typ :
     ('a, 'b) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
  -> 'd Nat.nat
  -> (('a, 'd) vec, ('b, 'd) vec) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t

(** Builds a Snarky type from a type [('a, 'n) t]*)
val wrap_typ' :
     (('var, 'value) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t, 'n) t
  -> (('var, 'n) t, ('value, 'n) t) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t

(** {1 Common interface of vectors } *)

val of_list : 'a list -> 'a e

val of_list_and_length_exn : 'a list -> 'n Nat.t -> ('a, 'n) t

val to_list : ('a, 'n) t -> 'a list

val sexp_of_t :
     ('a -> Ppx_sexp_conv_lib.Sexp.t)
  -> 'b
  -> ('a, 'c) t
  -> Ppx_sexp_conv_lib.Sexp.t

(** [zip v1 v2] combines together vectors [v1] and [v2] of length ['b].  *)
val zip : ('a, 'b) t -> ('c, 'b) t -> ('a * 'c, 'b) t

val init : 'a Nat.t -> f:(int -> 'b) -> ('b, 'a) t

val map : ('a, 'n) t -> f:('a -> 'b) -> ('b, 'n) t

val mapi : ('a, 'n) t -> f:(int -> 'a -> 'b) -> ('b, 'n) t

val map2 : ('a, 'n) t -> ('b, 'n) t -> f:('a -> 'b -> 'c) -> ('c, 'n) t

val mapn :
  'xs 'y 'n.
  ('xs, 'n) Hlist0.H1_1(T).t -> f:('xs Hlist0.HlistId.t -> 'y) -> ('y, 'n) t

val to_array : ('a, 'b) t -> 'a array

val foldi : ('a, 'b) t -> f:(int -> 'c -> 'a -> 'c) -> init:'c -> 'c

val fold : ('a, 'n) t -> f:('acc -> 'a -> 'acc) -> init:'acc -> 'acc

val reduce_exn : ('a, 'n) t -> f:('a -> 'a -> 'a) -> 'a

val iter : ('a, 'n) t -> f:('a -> unit) -> unit

val iteri : ('a, 'n) t -> f:(int -> 'a -> unit) -> unit

val iter2 : ('a, 'n) t -> ('b, 'n) t -> f:('a -> 'b -> unit) -> unit

val for_all : ('a, 'n) t -> f:('a -> bool) -> bool

(** [split v n] splits the vector [v] into two vectors [v1] and [v2] such that
    [v1] is of size [n] and [v2] is of size [m] where [length v = n + m] and [v1
    || v2 = v].

    [n] must have been constructed using {Kimchi_backend_types.Nat.I.add} whose result
    is equal the length of [v].
    More concretely:
    ```
    let six = Kimchi_backend_types.Nat.N6.n in
    let eleven = Kimchi_backend_types.Nat.N11.n in
    let v = Kimchi_backend_types.Vector.init eleven ~f:(fun i -> i) in
    (* will split v into two vectors, the first of size 5 and the second of size
       6
    *)
    let v_five, v_six =
      Kimchi_backend_types.Vector.split
        (* built using Nat.I.add *)
        v
        (snd (Kimchi_backend_types.Nat.N5.add six))
    in
    [...]
    ```
    The reason to construct the argument [n] with {add} is to correctly built at
    compile time an argument that will be smaller or equal to the size of [v].
*)
val split : ('a, 'n_m) t -> ('n, 'm, 'n_m) Nat.Adds.t -> ('a, 'n) t * ('a, 'm) t

val rev : ('a, 'n) t -> ('a, 'n) t

val length : ('a, 'n) t -> 'n Nat.t

val append :
  ('a, 'n) vec -> ('a, 'm) vec -> ('n, 'm, 'n_m) Nat.Adds.t -> ('a, 'n_m) vec

(** [singleton x] is [x] *)
val singleton : 'a -> ('a, Nat.z Nat.s) t

val unsingleton : ('a, Nat.z Nat.s) t -> 'a

val trim : 'a 'n 'm. ('a, 'm) vec -> ('n, 'm) Nat.Lte.t -> ('a, 'n) vec

val trim_front : 'a 'n 'm. ('a, 'm) vec -> ('n, 'm) Nat.Lte.t -> ('a, 'n) vec

val of_array_and_length_exn : 'a 'n. 'a array -> 'n Nat.t -> ('a, 'n) t

val extend :
  'a 'n 'm. ('a, 'n) vec -> ('n, 'm) Nat.Lte.t -> 'm Nat.t -> 'a -> ('a, 'm) vec

val extend_exn : 'a 'n 'm. ('a, 'n) vec -> 'm Nat.t -> 'a -> ('a, 'm) vec

val extend_front :
  'a 'n 'm. ('a, 'n) vec -> ('n, 'm) Nat.Lte.t -> 'm Nat.t -> 'a -> ('a, 'm) vec

val extend_front_exn : 'a 'n 'm. ('a, 'n) vec -> 'm Nat.t -> 'a -> ('a, 'm) vec

val transpose : 'a 'n 'm. (('a, 'n) vec, 'm) vec -> (('a, 'm) vec, 'n) vec

(** [nth v i] returns the [i]-th element [e] of vector [v]. The first element is
    at position 0.

    @return [None] if [i] is not a valid index for vector [v]
*)
val nth : ('a, 'n) vec -> int -> 'a option

(** [nth_exn v i] returns the [i]-th element of vector [v]. The first element is
    at position 0.

    @raise Invalid_argument if [i] is not a valid index for vector [v] *)
val nth_exn : ('a, 'n) vec -> int -> 'a
