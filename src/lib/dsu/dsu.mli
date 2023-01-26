open Core_kernel

module type Data = sig
  type t

  val merge : t -> t -> t
end

(** DSU data structure with ability to remove sets fromt he structure.contents
    
    For more information on design and usage of the DSU, see:
    https://www.notion.so/minaprotocol/Bit-catchup-algorithm-8a3fa7a2630c46d98505b25ebb20c8e7#e364c78e09c74c03835bc7ed8634dc47
*)
module Make : functor (Key : Hashtbl.Key) (D : Data) -> sig
  type element_t = { data : D.t option; parent : int; rank : int }

  type t

  val create : unit -> t

  val add_exn : key:Key.t -> data:D.t -> t -> unit

  val remove : key:Key.t -> t -> unit

  val get : key:Key.t -> t -> D.t option

  val union : a:Key.t -> b:Key.t -> t -> unit
end
