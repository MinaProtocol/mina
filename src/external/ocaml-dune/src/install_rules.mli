module type Params = sig
  val sctx : Super_context.t
end

(** Generate install rules for META and .install files *)
module Gen (P : Params) : sig
  val init : unit -> unit
end
