open Core

(* Written by debian packages and docker images. *)
let of_disk =
  try Some (In_channel.read_all "/etc/coda/build_config/PROFILE")
  with _ -> None

let of_runtime_env = Sys.getenv "MINA_PROFILE"

let profile_to_use =
  match List.find_map ~f:Fn.id [ of_runtime_env; of_disk ] with
  | None ->
      failwith
        "Node config: no profile set. Set MINA_PROFILE to one of dev, devnet, \
         lightnet, mainnet (installed packages provide \
         /etc/coda/build_config/PROFILE instead)."
  | Some "dev" ->
      (module Dev : Node_config_intf.Profiled)
  | Some "devnet" ->
      (module Devnet)
  | Some "lightnet" ->
      (module Lightnet)
  | Some "mainnet" ->
      (module Mainnet)
  | Some p ->
      failwithf "Node config: Invalid profile: %s" p ()

include (val profile_to_use)
