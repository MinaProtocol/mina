module type Field_intf = sig
  (** Represents an element of the field *)
  type t

  (** The number of bits in the field's order, i.e.
      [1 + log2(field_order)] *)
  val size_in_bits : int

  (** [negate x] returns the unique value [y] such that [x + y = zero mod p]
      where [p] is the order of the field *)
  val negate : t -> t

  (** [a - b] returns the unique value [c] such that [a + c = b mod p] where
      [p] is the order of the field *)
  val ( - ) : t -> t -> t

  (** [a + b] returns the unique value [c] such that [a + b = c mod p] where
      [p] is the order of the field *)
  val ( + ) : t -> t -> t

  (** [a * b] returns the unique value [c] such that [a * b = c mod p] where
      [p] is the order of the field *)
  val ( * ) : t -> t -> t

  (** [a / b] returns the unique value [c] such that [a * c = b mod p] where
      [p] is the order of the field *)
  val ( / ) : t -> t -> t

  (** [inv x] returns the unique value [y] such that [x * y = one mod p]
      where [p] is the order of the field *)
  val inv : t -> t

  (** The identity element for the addition *)
  val zero : t

  (** The identity element for the multiplication *)
  val one : t

  (** [of_int x] builds an element of type [t]. [x] is the canonical
      representation of the field element. *)
  val of_int : int -> t
end

module type S = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'f t [@@deriving sexp, compare, equal, yojson, hash]
    end
  end]

  type 'f t = 'f Stable.V1.t

  val typ :
       ('a, 'b, 'f) Snarky_backendless.Typ.t
    -> ('a t, 'b t, 'f) Snarky_backendless.Typ.t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  module Shift : sig
    type _ t

    val create : (module Field_intf with type t = 'f) -> 'f t

    (** [map x f] applies [f] on the value contained in [x] *)
    val map : 'a t -> f:('a -> 'b) -> 'b t
  end

  val of_field :
    (module Field_intf with type t = 'f) -> shift:'f Shift.t -> 'f -> 'f t

  val to_field :
    (module Field_intf with type t = 'f) -> shift:'f Shift.t -> 'f t -> 'f

  (* TODO: should this name be changed ? This is not exactly the expected
     signature for [equal] *)
  val equal : ('f, 'res) Sigs.rel2 -> ('f t, 'res) Sigs.rel2
end

module Type1 : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'f t = Shifted_value of 'f
      [@@deriving sexp, compare, equal, yojson, hash]
    end
  end]

  (** User beware: [equal] is not your regular equality predicate. *)
  val equal : ('a, 'res) Sigs.rel2 -> ('a t, 'res) Sigs.rel2

  val typ :
       ('a, 'b, 'f) Snarky_backendless.Typ.t
    -> ('a t, 'b t, 'f) Snarky_backendless.Typ.t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  module Shift : sig
    type _ t

    val create : (module Field_intf with type t = 'f) -> 'f t

    val map : 'a t -> f:('a -> 'b) -> 'b t
  end

  val of_field :
    (module Field_intf with type t = 'f) -> shift:'f Shift.t -> 'f -> 'f t

  val to_field :
    (module Field_intf with type t = 'f) -> shift:'f Shift.t -> 'f t -> 'f
end

module Type2 : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'f t = Shifted_value of 'f
      [@@deriving sexp, compare, equal, yojson, hash]
    end
  end]

  (** User beware: [equal] is not your regular equality predicate. It's just a
      binary relation.
   *)
  val equal : ('a, 'res) Sigs.rel2 -> ('a t, 'res) Sigs.rel2

  val typ :
       ('a, 'b, 'f) Snarky_backendless.Typ.t
    -> ('a t, 'b t, 'f) Snarky_backendless.Typ.t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  module Shift : sig
    type _ t

    val create : (module Field_intf with type t = 'f) -> 'f t

    val map : 'a t -> f:('a -> 'b) -> 'b t
  end

  val of_field :
    (module Field_intf with type t = 'f) -> shift:'f Shift.t -> 'f -> 'f t

  val to_field :
    (module Field_intf with type t = 'f) -> shift:'f Shift.t -> 'f t -> 'f
end
