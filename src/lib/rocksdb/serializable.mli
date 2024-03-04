module Make (Key : Binable.S) (Value : Binable.S) :
  Key_value_database.Intf.S
    with module M := Key_value_database.Monad.Ident
     and type key := Key.t
     and type value := Value.t
     and type config := string

module GADT : sig
  module Make (Key : Intf.Key.S) : Intf.Database.S with type 'a g := 'a Key.t
end
