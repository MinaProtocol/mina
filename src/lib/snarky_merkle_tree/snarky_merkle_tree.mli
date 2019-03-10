open Snarky

module Index : sig
  type 'f t
end

type 'h t

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
    end) : sig
  module Index : sig
    type t = M.field Index.t

    type value = int

    val typ : depth:int -> (t, value) M.Typ.t
  end

  type nonrec t = Hash.t t

  val root : t -> Hash.t

  val create : depth:int -> root:Hash.t -> t

  val modify : t -> Index.t -> f:(Elt.t -> Elt.t) -> t

  type _ Request.t +=
    | Get_element : Index.value -> (Elt.value * Hash.value list) Request.t
    | Get_path : Index.value -> Hash.value list Request.t
    | Set : Index.value * Elt.value -> unit Request.t
end
