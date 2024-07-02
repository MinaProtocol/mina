open Integration_test_lib

module DockerContext = struct
  type t =
    { image : string; workdir : string; volume : string; network : string }
end

type context =
  | Dune (* application ran from dune exec command *)
  | Local (* application ran from _build/default folder*)
  | Debian (* application installed from mina debian package *)
  | Docker of DockerContext.t
  | AutoDetect
(* application ran inside docker container *)

module Executor = struct
  type t = { official_name : string; dune_name : string; context : context }

  let of_context ~context ~dune_name ~official_name =
    { context; dune_name; official_name }

  let run_from_debian t ~(args:string list) ?(env=`Extend []) =
    Util.run_cmd_exn "." t.official_name args ~env  
   
  let run_from_dune t ~(args:string list) ?(env=`Extend []) =
    Util.run_cmd_exn "." "dune" ([ "exec"; t.dune_name; "--" ] @ args ) ~env   
  
  let run_from_local t ~(args:string list) ?(env=`Extend []) =
    Util.run_cmd_exn "." (Printf.sprintf "_build/default/%s" t.dune_name) args ~env   
    
  let built_name t = 
    (Printf.sprintf "_build/default/%s" t.dune_name)

  let run t ~(args:string list) ?(env=`Extend [])=
    match t.context with
    | AutoDetect -> 
        if Sys.file_exists (built_name t) then 
          run_from_local t ~args ~env  
        else if Sys.file_exists t.official_name then
          run_from_debian t ~args ~env
        else
          run_from_dune t ~args ~env
    | Dune ->
        run_from_dune t ~args ~env
    | Debian ->
        run_from_debian t ~args ~env
    | Local -> 
        run_from_local t ~args ~env
    | Docker ctx ->
        let docker = Docker.Client.default in
        let cmd = [ t.official_name ] @ args in
        Docker.Client.run_cmd_in_image docker ~image:ctx.image ~cmd
          ~workdir:ctx.workdir ~volume:ctx.volume ~network:ctx.network
end
