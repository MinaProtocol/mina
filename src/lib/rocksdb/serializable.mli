module Make (Key : Binable.S) (Value : Binable.S) :
  Key_value_database.Intf.S
    with module M := Key_value_database.Monad.Ident
     and type key := Key.t
     and type value := Value.t
     and type config := string

module GADT : sig
  module type Database_intf = sig
    type t

    type 'a g

    val set : t -> key:'a g -> data:'a -> unit

    val set_raw : t -> key:'a g -> data:Bigstring.t -> unit

    val remove : t -> key:'a g -> unit
  end

  module type S = sig
    include Database_intf

    module Some_key : Key_intf.Some_key_intf with type 'a unwrapped_t := 'a g

    module T : sig
      type nonrec t = t
    end

    val create : string -> t

    val close : t -> unit

    val get : t -> key:'a g -> 'a option

    val get_raw : t -> key:'a g -> Bigstring.t option

    val get_batch : t -> keys:Some_key.t list -> Some_key.with_value option list

    module Batch : sig
      include Database_intf with type 'a g := 'a g

      val with_batch : T.t -> f:(t -> 'a) -> 'a
    end
  end

  module Make (Key : Key_intf.S) : S with type 'a g := 'a Key.t
end
