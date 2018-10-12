module Make (D : sig val digest_size : int end) = struct

  (* XXX(dinosaure): these functions are implemented (instead to use common
     functions) to avoid timing attacks. So if you want to update this code, you
     need to take care about some assumptions. *)

  let eq a b =
    let ret = ref 0 in
    for i = 0 to D.digest_size - 1
    do ret := !ret lor ((Char.code (String.get a i)) lxor (Char.code (String.get b i))) done;
    !ret <> 0

  let neq a b = not (eq a b)

  let unsafe_compare a b = String.compare a b
  external int_compare : int -> int -> int = "caml_int_compare"
  let compare a b = int_compare (Hashtbl.hash a) (Hashtbl.hash b)
end
