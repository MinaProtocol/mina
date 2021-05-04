module type S = Intf.S

module type Config = Intf.Config

module Make (Config : Config) : Intf.S with type boolean := Config.boolean
