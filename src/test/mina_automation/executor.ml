(**
Core module to run any defined app on various contexts
*)

open Integration_test_lib
open Core_kernel
open Async


module type AppPaths = sig
  val dune_name : string

  val official_name : string
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

  let in_background ?(prefix = "") ~app ~(args : string list) ?env ()
      =
    let full_path =
      if String.is_empty prefix then app
      else prefix ^ "/" ^ app
    in
    log_executed_command full_path ;
    (full_path , (Util.create_process_exn ?env "." full_path args ()) )

    let output_or_hard_error ~prog ~args output =
      match%map Util.check_cmd_output ~prog ~args output with
      | Ok output ->
          output
      | Error error ->
          Error.raise error
  

    let ignore_or_hard_error ~prog ~args (output : Process.Output.t) ~ignore_failure =
      if ignore_failure then return output.stdout
      else output_or_hard_error ~prog ~args output

  let to_foreground ~process ~prog ~(args : string list) ?(ignore_failure = false) () =
      let%bind output = process >>= Process.collect_output_and_wait
      in
      ignore_or_hard_error ~prog ~args output ~ignore_failure

  let run_from_local_in_background ~(args : string list) ?prefix ?env () =
    in_background ?prefix ~app:PathFinder.built_name ~args ?env ()

  let run_from_dune_in_background ~args ?prefix ?env () =
    in_background ?prefix ~app:"dune" ~args:([ "exec"; PathFinder.Paths.dune_name; "--" ] @ args) ?env ()
    
  let run_from_debian_in_background ?prefix ~(args : string list) ?env () =
    in_background ?prefix ~app:PathFinder.Paths.official_name ~args ?env ()

  let run_from_docker ~(ctx:DockerContext.t) ~args ?env ()  =
    let docker = Docker.Client.default in
        let cmd = [ P.official_name ] @ args in
        Docker.Client.run_cmd_in_image docker ~image:ctx.image ~cmd
          ~workdir:ctx.workdir ~volume:ctx.volume ~network:ctx.network

  let run_impl t ~(args : string list) ?env 
    ~f_local:(string list : Unix.env -> string * Process.t Deferred.t) 
    ~f_debian ~f_dune ~f_docker () =
    let open Deferred.Let_syntax in
    match t with
    | AutoDetect -> (
        match%bind Sys.file_exists PathFinder.built_name with
        | `Yes ->
            f_local ~args ~prefix:"" ?env ()
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
        f_local ~args ~prefix:"" ?env ()
    | Docker ctx ->
        f_docker ~args ~prefix:"" ~ctx ?env ()


  let run_in_background t ~(args : string list) ?env () =
    let _,process = run_impl t ~args ?env ~f_local:(fun ~args ~prefix ?env () : (string * Process.t Deferred.t ) -> run_from_local_in_background ~args ~prefix ?env ())
    ~f_debian:(run_from_debian_in_background) 
    ~f_dune:(run_from_dune_in_background)
    ~f_docker:(fun ~_ctx ~_args ?_env () -> failwith
    "Cannot run docker in background yet. Maybe you need \
     src/app/test_executive approach?") ()
    in 
      process
    
  let run t ?ignore_failure ~(args : string list) ?env () =
    let prog,process = run_impl t ~args ?env ~f_local:(run_from_local_in_background ?ignore_failure)
        ~f_debian:(run_from_debian_in_background ?ignore_failure) 
        ~f_dune:(run_from_dune_in_background  ?ignore_failure)
        ~f_docker:(fun ~_ctx ~_args ?_env () -> failwith
        "Cannot run docker in background yet. Maybe you need \
         src/app/test_executive approach?") ()
    in
     to_foreground ~process ~prog ~args ?ignore_failure ()

end
