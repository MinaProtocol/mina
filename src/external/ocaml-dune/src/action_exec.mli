open! Stdune

val exec
  :  targets:Path.Set.t
  -> context:Context.t option
  -> env:Env.t option
  -> Action.t
  -> unit Fiber.t
