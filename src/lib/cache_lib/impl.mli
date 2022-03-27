module type Inputs_intf = sig
  val handle_unconsumed_cache_item :
    logger:Logger.t -> cache_name:string -> unit
end

module Make : functor (Inputs : Inputs_intf) -> Intf.Main.S
