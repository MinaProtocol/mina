open Integration_test_lib

module DockerContext = struct
  type t =
    { image : string; workdir : string; volume : string; network : string }
end

type context =
  | Dune (* application ran from dune exec command *)
  | Debian (* application installed from mina debian package *)
  | Docker of DockerContext.t
(* application ran inside docker container *)

module Executor = struct
  type t = { official_name : string; dune_name : string; context : context }

  let of_context ~context ~dune_name ~official_name =
    { context; dune_name; official_name }

  let run t ~args =
    match t.context with
    | Dune ->
        Util.run_cmd_exn "." "dune" ([ "exec"; t.dune_name; "--" ] @ args)
    | Debian ->
        Util.run_cmd_exn "." t.official_name args
    | Docker ctx ->
        let docker = Docker.Client.default in
        let cmd = [ t.official_name ] @ args in
        Docker.Client.run_cmd_in_image docker ~image:ctx.image ~cmd
          ~workdir:ctx.workdir ~volume:ctx.volume ~network:ctx.network
end
