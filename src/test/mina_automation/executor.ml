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

module type AppPaths = sig
  (** The name of the application as it appears in the dune file. *)
  val dune_name : string

  (** The name of the application as it appears in the debian package or docker image. *)
  val official_name : string
end

let logger = Logger.create ()

module PathFinder = struct
  let paths =
    Option.value_map ~f:(String.split ~on:':') ~default:[] (Sys.getenv "PATH")

  let built_name app_name_under_dune =
    Printf.sprintf "_build/default/%s" app_name_under_dune

  let exists_at_path path prefix =
    match%bind Sys.file_exists (prefix ^ "/" ^ path) with
    | `Yes ->
        Deferred.return (Some prefix)
    | _ ->
        Deferred.return None

  let standalone_path official_name =
    match%bind Sys.file_exists (built_name official_name) with
    | `Yes ->
        Deferred.return (Some (built_name official_name))
    | _ -> (
        match%bind
          Deferred.List.find_map ~f:(exists_at_path official_name) paths
        with
        | Some _ ->
            Deferred.return (Some official_name)
        | _ ->
            Deferred.return None )

  let standalone_path_exn official_name =
    Deferred.map (standalone_path official_name) ~f:(fun opt ->
        Option.value_exn opt
          ~message:
            "Could not find standalone path. App is not executable outside the \
             dune" )
end

module Make (P : AppPaths) = struct
  type t =
    | Dune (* application ran from dune exec command *)
    | Local (* application ran from _build/default folder*)
    | Debian (* application installed from mina debian package *)
    | Docker of DockerContext.t (* application ran inside docker container *)
    | AutoDetect (* application ran from any of the above *)

  module P = P
  module PathFinder = PathFinder

  let default = AutoDetect

  let log_executed_command path =
    [%log debug] "Executing mina application"
      ~metadata:[ ("app", `String path) ]

  let run_from_debian ?(prefix = "") ~(args : string list) ?env () =
    let full_path =
      if String.is_empty prefix then P.official_name
      else prefix ^ "/" ^ P.official_name
    in
    log_executed_command full_path ;
    Util.run_cmd_exn ?env "." full_path args

  let run_from_dune ~(args : string list) ?env () =
    log_executed_command P.dune_name ;
    Util.run_cmd_exn ?env "." "dune" ([ "exec"; P.dune_name; "--" ] @ args)

  let run_from_local ~(args : string list) ?env () =
    log_executed_command (PathFinder.built_name P.official_name) ;
    Util.run_cmd_exn ?env "." (PathFinder.built_name P.official_name) args

  let run t ~(args : string list) ?env () =
    let open Deferred.Let_syntax in
    match t with
    | AutoDetect -> (
        match%bind Sys.file_exists (PathFinder.built_name P.official_name) with
        | `Yes ->
            run_from_local ~args ?env ()
        | _ -> (
            match%bind
              Deferred.List.find_map
                ~f:(PathFinder.exists_at_path P.official_name)
                PathFinder.paths
            with
            | Some prefix ->
                run_from_debian ~prefix ~args ?env ()
            | _ ->
                run_from_dune ~args ?env () ) )
    | Dune ->
        run_from_dune ~args ?env ()
    | Debian ->
        run_from_debian ~args ?env ()
    | Local ->
        run_from_local ~args ?env ()
    | Docker ctx ->
        let docker = Docker.Client.default in
        let cmd = [ P.official_name ] @ args in
        Docker.Client.run_cmd_in_image docker ~image:ctx.image ~cmd
          ~workdir:ctx.workdir ~volume:ctx.volume ~network:ctx.network
end
