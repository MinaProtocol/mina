module type Field_intf = sig
  type t

  val size_in_bits : int

  val negate : t -> t

  val ( - ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val inv : t -> t

  val one : t

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

  (** User beware: [equal] is not your regular equality predicate. 
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

(** [Type2] *)
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

      FIXME: change this name
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
