(**
Core module to run any defined app on various contexts
*)

open Integration_test_lib
open Core_kernel
open Async

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

  let run_from_debian t ~(args : string list) ?env () =
    Util.run_cmd_exn ?env "." t.official_name args

  let run_from_dune t ~(args : string list) ?env () =
    Util.run_cmd_exn ?env "." "dune" ([ "exec"; t.dune_name; "--" ] @ args)

  let run_from_local t ~(args : string list) ?env () =
    Util.run_cmd_exn ?env "."
      (Printf.sprintf "_build/default/%s" t.dune_name)
      args

  let built_name t = Printf.sprintf "_build/default/%s" t.dune_name

  let paths =
    Option.value_map ~f:(String.split ~on:':') ~default:[] (Sys.getenv "PATH")

  let exists_at_path t prefix =
    match%bind Sys.file_exists (prefix ^ "/" ^ t.official_name) with
    | `Yes ->
        Deferred.return (Some prefix)
    | _ ->
        Deferred.return None

  let path t =
    match%bind Sys.file_exists (built_name t) with
    | `Yes ->
        Deferred.return (built_name t)
    | _ -> (
        match%bind Deferred.List.find_map ~f:(exists_at_path t) paths with
        | Some _ ->
            Deferred.return t.official_name
        | _ ->
            Deferred.return t.dune_name )

  let run t ~(args : string list) ?env () =
    let open Deferred.Let_syntax in
    let logger = Logger.create () in
    match t.context with
    | AutoDetect -> (
        match%bind Sys.file_exists (built_name t) with
        | `Yes ->
            [%log debug] "running from _build/default folder"
              ~metadata:[ ("app", `String (built_name t)) ] ;
            run_from_local t ~args ?env ()
        | _ -> (
            match%bind Deferred.List.find_map ~f:(exists_at_path t) paths with
            | Some prefix ->
                [%log debug] "running from %s" prefix
                  ~metadata:[ ("app", `String t.official_name) ] ;
                run_from_debian t ~args ?env ()
            | _ ->
                [%log debug] "running from src/.. folder"
                  ~metadata:[ ("app", `String t.dune_name) ] ;
                run_from_dune t ~args ?env () ) )
    | Dune ->
        run_from_dune t ~args ?env ()
    | Debian ->
        run_from_debian t ~args ?env ()
    | Local ->
        run_from_local t ~args ?env ()
    | Docker ctx ->
        let docker = Docker.Client.default in
        let cmd = [ t.official_name ] @ args in
        Docker.Client.run_cmd_in_image docker ~image:ctx.image ~cmd
          ~workdir:ctx.workdir ~volume:ctx.volume ~network:ctx.network
end
