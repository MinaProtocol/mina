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

(* application ran inside docker container *)

module type AppPaths = sig
  val dune_name : string

  val official_name : string
end

let logger = Logger.create ()

module Make_PathFinder (P : AppPaths) = struct
  module Paths = P

  let paths =
    Option.value_map ~f:(String.split ~on:':') ~default:[] (Sys.getenv "PATH")

  let built_name = Printf.sprintf "_build/default/%s" P.dune_name

  let exists_at_path path prefix =
    match%bind Sys.file_exists (prefix ^ "/" ^ path) with
    | `Yes ->
        Deferred.return (Some prefix)
    | _ ->
        Deferred.return None

  let standalone_path =
    match%bind Sys.file_exists built_name with
    | `Yes ->
        Deferred.return (Some built_name)
    | _ -> (
        match%bind
          Deferred.List.find_map ~f:(exists_at_path P.official_name) paths
        with
        | Some _ ->
            Deferred.return (Some P.official_name)
        | _ ->
            Deferred.return None )

  let standalone_path_exn =
    Deferred.map standalone_path ~f:(fun opt ->
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
    | Docker of DockerContext.t
    | AutoDetect

  module PathFinder = Make_PathFinder (P)

  let default = AutoDetect

  let log_executed_command path =
    [%log debug] "Executing mina application"
      ~metadata:[ ("app", `String path) ]

  let run_from_local_in_background ~(args : string list) ?env () =
    log_executed_command PathFinder.built_name ;
    Util.create_process_exn ?env "." PathFinder.built_name args ()

  let output_or_hard_error ~prog ~args output =
    match%map Util.check_cmd_output ~prog ~args output with
    | Ok output ->
        output
    | Error error ->
        Error.raise error

  let run_from_local ~(args : string list) ?env ?(ignore_failure = false) () =
    let%bind output =
      run_from_local_in_background ~args ?env ()
      >>= Process.collect_output_and_wait
    in
    if ignore_failure then return output.stdout
    else output_or_hard_error ~prog:PathFinder.built_name ~args output

  let run_from_debian_in_background ?(prefix = "") ~(args : string list) ?env ()
      =
    let full_path =
      if String.is_empty prefix then PathFinder.Paths.official_name
      else prefix ^ "/" ^ PathFinder.Paths.official_name
    in
    log_executed_command full_path ;
    Util.create_process_exn ?env "." full_path args ()

  let run_from_debian ?(prefix = "") ~(args : string list) ?env
      ?(ignore_failure = false) () =
    let%bind output =
      run_from_debian_in_background ~prefix ~args ?env ()
      >>= Process.collect_output_and_wait
    in
    if ignore_failure then return output.stdout
    else output_or_hard_error ~prog:PathFinder.Paths.official_name ~args output

  let run_from_dune_in_background ~args ?env () =
    log_executed_command PathFinder.Paths.dune_name ;
    Util.create_process_exn ?env "." "dune"
      ([ "exec"; PathFinder.Paths.dune_name; "--" ] @ args)
      ()

  let run_from_dune ~(args : string list) ?env ?(ignore_failure = false) () =
    let%bind output =
      run_from_dune_in_background ~args ?env ()
      >>= Process.collect_output_and_wait
    in
    if ignore_failure then return output.stdout
    else output_or_hard_error ~prog:PathFinder.Paths.dune_name ~args output

  let run t ~(args : string list) ?env ?ignore_failure () =
    let open Deferred.Let_syntax in
    match t with
    | AutoDetect -> (
        match%bind Sys.file_exists PathFinder.built_name with
        | `Yes ->
            run_from_local ~args ?env ?ignore_failure ()
        | _ -> (
            match%bind
              Deferred.List.find_map
                ~f:(PathFinder.exists_at_path PathFinder.Paths.official_name)
                PathFinder.paths
            with
            | Some prefix ->
                run_from_debian ~prefix ~args ?env ?ignore_failure ()
            | _ ->
                run_from_dune ~args ?env ?ignore_failure () ) )
    | Dune ->
        run_from_dune ~args ?env ?ignore_failure ()
    | Debian ->
        run_from_debian ~args ?env ?ignore_failure ()
    | Local ->
        run_from_local ~args ?env ?ignore_failure ()
    | Docker ctx ->
        let docker = Docker.Client.default in
        let cmd = [ P.official_name ] @ args in
        Docker.Client.run_cmd_in_image docker ~image:ctx.image ~cmd
          ~workdir:ctx.workdir ~volume:ctx.volume ~network:ctx.network

  let run_in_background t ~(args : string list) ?env () =
    let open Deferred.Let_syntax in
    match t with
    | AutoDetect -> (
        match%bind Sys.file_exists PathFinder.built_name with
        | `Yes ->
            run_from_local_in_background ~args ?env ()
        | _ -> (
            match%bind
              Deferred.List.find_map
                ~f:(PathFinder.exists_at_path PathFinder.Paths.official_name)
                PathFinder.paths
            with
            | Some prefix ->
                run_from_debian_in_background ~prefix ~args ?env ()
            | _ ->
                run_from_dune_in_background ~args ?env () ) )
    | Dune ->
        run_from_dune_in_background ~args ?env ()
    | Debian ->
        run_from_debian_in_background ~args ?env ()
    | Local ->
        run_from_local_in_background ~args ?env ()
    | Docker _ctx ->
        failwith
          "Cannot run docker in background yet. Maybe you need \
           src/app/test_executive approach?"
end
