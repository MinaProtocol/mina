module Make (Key : sig
  type _ t

  val compare : _ t -> _ t -> int

  val hash : _ t -> int

  val sexp_of_t : _ t -> Sexp.t
end) =
struct
  type e = E : 'a -> e

  let unsafe_cast (E x : e) : 'a = Obj.magic x

  module KeyE = struct
    type t = EK : 'a Key.t -> t

    let compare (EK lhs : t) (EK rhs : t) = Key.compare lhs rhs

    let hash (EK key) = Key.hash key

    let sexp_of_t (EK key) = Key.sexp_of_t key
  end

  type table = (KeyE.t, e) Hashtbl.t

  let create () = Hashtbl.create (module KeyE)

  let find (type a) (tbl : table) (key : a Key.t) : a option =
    let%map.Option v = Hashtbl.find tbl (KeyE.EK key) in
    unsafe_cast v

  let set (type a) (tbl : table) ~(key : a Key.t) ~(data : a) =
    Hashtbl.set tbl ~key:(KeyE.EK key) ~data:(E data)
end
