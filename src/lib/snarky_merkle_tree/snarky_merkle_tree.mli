open Snarky

module Index : sig
  type 'f t
end

type ('h, 'a) t

module type S = sig
  module M : Snark_intf.Run

  module Hash : sig
    type t

    type value
  end

  module Elt : sig
    type t

    type value
  end

  module Index : sig
    type t = M.field Index.t

    type value = int

    val of_field_exn : depth:int -> M.Field.t -> t

    val to_field : t -> M.Field.t

    val typ : depth:int -> (t, value) M.Typ.t
  end

  type nonrec t = (Hash.t, Elt.t) t

  val root : t -> Hash.t

  val create : depth:int -> root:Hash.t -> t

  val max_size : t -> int

  val depth : t -> int

  val modify : t -> Index.t -> f:(Elt.t -> Elt.t) -> t

  type _ Request.t +=
    | Get_element : Index.value -> (Elt.value * Hash.value list) Request.t
    | Get_path : Index.value -> Hash.value list Request.t
    | Set : Index.value * Elt.value -> unit Request.t
end

module Make
    (M : Snark_intf.Run) (Hash : sig
        type t

        type value

        val typ : (t, value) M.Typ.t

        val compress : height:int -> t -> t -> t

        val if_ : M.Boolean.var -> then_:t -> else_:t -> t

        module Assert : sig
          val equal : t -> t -> unit
        end
    end) (Elt : sig
      type t

      type value

      val typ : (t, value) M.Typ.t

      val hash : t -> Hash.t
    end) : S with module M = M and module Hash = Hash and module Elt = Elt
