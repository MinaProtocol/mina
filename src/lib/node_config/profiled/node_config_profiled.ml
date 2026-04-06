open Core

let profile_to_use =
  match Comptime.dune_profile |> Option.value ~default:"dev" with
  | "dev" ->
      (module Dev : Node_config_intf.Profiled)
  | "devnet" ->
      (module Devnet)
  | "lightnet" ->
      (module Lightnet)
  | "mainnet" ->
      (module Mainnet)
  | p ->
      failwithf "Invalid dune profile: %s" p ()

include (val profile_to_use)
