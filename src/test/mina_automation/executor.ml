(**
Core module to run any defined app on various contexts
*)

open Integration_test_lib
open Core_kernel
open Async

module type AppPaths = sig
  (** The name of the application as it appears in the dune file. *)
  val dune_name : string

  (** The name of the application as it appears in the debian package or docker image. *)
  val official_name : string
end

module type PathFinder = sig
  module Paths : AppPaths

  val standalone_path : string option Deferred.t

  val standalone_path_exn : string Deferred.t
end

(* application ran inside docker container *)
module DockerContext = struct
  type t =
    { image : string; workdir : string; volume : string; network : string }
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
end

module Make (P : AppPaths) = struct
  type t =
    | Dune (* application ran from dune exec command *)
    | Local (* application ran from _build/default folder*)
    | Debian (* application installed from mina debian package *)
    | Docker of DockerContext.t (* application ran inside docker container *)
    | AutoDetect
  (* application ran from any of the above *)

  module PathFinder = Make_PathFinder (P)

  let default = AutoDetect

  let log_executed_command path =
    [%log debug] "Executing mina application"
      ~metadata:[ ("app", `String path) ]

  let in_background ?(prefix = "") ~app ~(args : string list) ?env () =
    let full_path =
      if String.is_empty prefix then app else prefix ^ "/" ^ app
    in
    log_executed_command full_path ;
    Util.create_process_exn ?env "." full_path args ()
    |> Deferred.map ~f:(fun process -> (full_path, process))

  let output_or_hard_error ~prog ~args output =
    match%map Util.check_cmd_output ~prog ~args output with
    | Ok output ->
        output
    | Error error ->
        Error.raise error

  let ignore_or_hard_error ~prog ~args (output : Process.Output.t)
      ~ignore_failure =
    if ignore_failure then return output.stdout
    else output_or_hard_error ~prog ~args output

  let run_from_local_in_background ~(args : string list) ?prefix ?env () =
    in_background ?prefix ~app:PathFinder.built_name ~args ?env ()

  let run_from_dune_in_background ~args ?prefix ?env () =
    in_background ?prefix ~app:"dune"
      ~args:([ "exec"; PathFinder.Paths.dune_name; "--" ] @ args)
      ?env ()

  let run_from_debian_in_background ?prefix ~(args : string list) ?env () =
    in_background ?prefix ~app:PathFinder.Paths.official_name ~args ?env ()

  let run_from_docker ~(ctx : DockerContext.t) ~args () =
    let docker = Docker.Client.default in
    let cmd = [ P.official_name ] @ args in
    Docker.Client.run_cmd_in_image docker ~image:ctx.image ~cmd
      ~workdir:ctx.workdir ~volume:ctx.volume ~network:ctx.network

  let run_impl t ~(args : string list) ?env ~f_local ~f_debian ~f_dune ~f_docker
      () =
    let open Deferred.Let_syntax in
    match t with
    | AutoDetect -> (
        match%bind Sys.file_exists PathFinder.built_name with
        | `Yes ->
            f_local ~args ~prefix:PathFinder.built_name ?env ()
        | _ -> (
            match%bind
              Deferred.List.find_map
                ~f:(PathFinder.exists_at_path PathFinder.Paths.official_name)
                PathFinder.paths
            with
            | Some prefix ->
                f_debian ~args ~prefix ?env ()
            | _ ->
                f_dune ~args ~prefix:"" ?env () ) )
    | Dune ->
        f_dune ~args ~prefix:"" ?env ()
    | Debian ->
        f_debian ~args ~prefix:"" ?env ()
    | Local ->
        f_local ~args ~prefix:PathFinder.built_name ?env ()
    | Docker ctx ->
        f_docker ~args ~ctx ()

  let run_in_background t ~(args : string list) ?env () =
    run_impl t ~args ?env
      ~f_local:(fun ~args ~prefix ?env () ->
        run_from_local_in_background ~args ~prefix ?env () )
      ~f_debian:(fun ~args ~prefix ?env () ->
        run_from_debian_in_background ~args ~prefix ?env () )
      ~f_dune:(fun ~args ~prefix ?env () ->
        run_from_dune_in_background ~args ~prefix ?env () )
      ~f_docker:(fun ~args:_ ~ctx:_ () ->
        raise
          (Failure
             "Cannot run docker in background yet. Maybe you need \
              src/app/test_executive approach?" ) )
      ()

  let run t ~(args : string list) ?env ?ignore_failure () =
    let open Deferred.Let_syntax in
    let to_foreground_process (prog, process) =
      let%bind output = Process.collect_output_and_wait process in
      ignore_or_hard_error ~prog ~args output
        ~ignore_failure:(Option.value ~default:false ignore_failure)
    in

    run_impl t ~args ?env
      ~f_local:(fun ~args ~prefix ?env () ->
        run_from_local_in_background ~args ~prefix ?env ()
        >>= to_foreground_process )
      ~f_debian:(fun ~args ~prefix ?env () ->
        run_from_debian_in_background ~args ~prefix ?env ()
        >>= to_foreground_process )
      ~f_dune:(fun ~args ~prefix ?env () ->
        run_from_dune_in_background ~args ~prefix ?env ()
        >>= to_foreground_process )
      ~f_docker:(fun ~args ~ctx () -> run_from_docker ~args ~ctx ())
      ()
end
