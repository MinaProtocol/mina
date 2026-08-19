open Core_kernel

(* This is for backward compatibility, when everyone migrate to the "unprofiled"
   build and set MINA_PROFILE on their own, we should be able to remove this. *)
let of_disk =
  try Some (In_channel.read_all "/etc/coda/build_config/PROFILE")
  with _ -> None

(* This should be the preferred way to resolve node profile, at least for now. *)
let of_runtime_env = Sys.getenv_opt "MINA_PROFILE"

let profile_to_use =
  match
    List.find_map ~f:Fn.id [ of_runtime_env; of_disk ]
    |> Option.value ~default:"dev"
  with
  | "dev" ->
      (* NOTE: this is also used at compile time, for code generation, e.g. graphQL schema *)
      (module Dev : Node_config_intf.Profiled)
  | "devnet" ->
      (module Devnet)
  | "lightnet" ->
      (module Lightnet)
  | "mainnet" ->
      (module Mainnet)
  | p ->
      failwithf "Node config: Invalid profile: %s" p ()

include (val profile_to_use)
