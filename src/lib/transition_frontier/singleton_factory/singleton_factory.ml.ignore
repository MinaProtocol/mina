(* 2019: programming OCaml likes it's Java (good ol' AbstractSingletonProxyFactoryBean) *)

module type Interface_intf = sig
  module type Base with type t
end

module Singleton_factory_intf = sig
end

module Make_singleton_factory
  (Interface : Interface_intf)
  (Def : sig
    include Interface.Intf
    include Singleton_factory_intf with type t := t
  end)
(Def : Singleton_factory_definition_intf)
