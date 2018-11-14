open Core
open Async

type 'a value = {path: string; value: 'a; checksum: Md5.t}

let try_load bin_t path =
  let logger = Logger.create () in
  let controller = Storage.Disk.Controller.create ~parent_log:logger bin_t in
  match%map Storage.Disk.load_with_checksum controller path with
  | Ok {Storage.Checked_data.data; checksum} ->
      Logger.info logger "Loaded value successfully from %s" path ;
      Ok {path; value= data; checksum}
  | Error `Checksum_no_match -> Or_error.error_string "Checksum failure"
  | Error ((`IO_error _ | `No_exist) as err) -> (
    match err with
    | `IO_error e ->
        Or_error.errorf "Could not load value. The error was: %s"
          (Error.to_string_hum e)
    | `No_exist ->
        Or_error.error_string "Cached value not found in default location" )

module Component = struct
  type (_, 'env) t =
    | Load :
        { label: string
        ; f: 'env -> 'a
        ; bin_t: 'a Bin_prot.Type_class.t }
        -> ('a value, 'env) t

  let load (Load {label; f= _; bin_t}) ~base_path =
    let path = base_path ^ "_" ^ label in
    try_load bin_t path

  let store (Load {label; f; bin_t}) ~base_path ~env =
    let path = base_path ^ "_" ^ label in
    let logger = Logger.create () in
    let controller = Storage.Disk.Controller.create ~parent_log:logger bin_t in
    let value = f env in
    let%map checksum =
      Storage.Disk.store_with_checksum controller path value
    in
    {path; value; checksum}
end

module With_components = struct
  module T = struct
    type ('a, 'env) t =
      | Pure : 'a -> ('a, 'env) t
      | Ap : ('a, 'env) Component.t * ('a -> 'b, 'env) t -> ('b, 'env) t

    let return x = Pure x

    let rec map : type a b e. (a, e) t -> f:(a -> b) -> (b, e) t =
     fun t ~f ->
      match t with
      | Pure x -> Pure (f x)
      | Ap (c, t1) -> Ap (c, map t1 ~f:(fun g x -> f (g x)))

    let rec apply : type a b e. (a -> b, e) t -> (a, e) t -> (b, e) t =
     fun t1 t2 ->
      match (t1, t2) with
      | Pure f, y -> map ~f y
      | Ap (x, y), z -> Ap (x, apply (map y ~f:Fn.flip) z)

    let map = `Define_using_apply
  end

  include T
  include Applicative.Make2 (T)

  let rec load : type a e.
      (a, e) t -> base_path:string -> a Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    fun t ~base_path ->
      match t with
      | Pure x -> return x
      | Ap ((Load _ as c), tf) ->
          let%map x = Component.load c ~base_path and f = load tf ~base_path in
          f x

  let rec store : type a e.
      (a, e) t -> base_path:string -> env:e -> a Deferred.t =
    let open Deferred.Let_syntax in
    fun t ~base_path ~env ->
      match t with
      | Pure x -> return x
      | Ap ((Load _ as c), tf) ->
          let%map x = Component.store c ~base_path ~env
          and f = store tf ~base_path ~env in
          f x

  module Let_syntax = struct
    let return = return

    module Let_syntax = struct
      let return = return

      let map = map

      let both t1 t2 = apply (map t1 ~f:(fun x y -> (x, y))) t2

      module Open_on_rhs = struct end
    end
  end
end

include With_components

type ('a, 'e) cached = ('a, 'e) t

let component ~label ~f bin_t =
  Ap (Component.Load {label; f; bin_t}, Pure Fn.id)

module Spec = struct
  type 'a t =
    | T :
        { load: ('a, 'env) With_components.t
        ; name: string
        ; autogen_path: string
        ; manual_install_path: string
        ; digest_input: 'input -> string
        ; create_env: 'input -> 'env
        ; input: 'input }
        -> 'a t

  let create ~load ~name ~autogen_path ~manual_install_path ~digest_input
      ~create_env ~input =
    T
      { load
      ; name
      ; autogen_path
      ; manual_install_path
      ; digest_input
      ; create_env
      ; input }
end

let run
    (Spec.T
      { load
      ; name
      ; autogen_path
      ; manual_install_path
      ; digest_input
      ; create_env
      ; input }) =
  let open Deferred.Let_syntax in
  let hash = digest_input input in
  let base_path directory = directory ^/ hash in
  match%bind
    With_components.load load ~base_path:(base_path manual_install_path)
  with
  | Ok x ->
      Core.printf "Loaded %s from manual installation path %s\n" name
        manual_install_path ;
      return x
  | Error _e -> (
      Core.printf
        "Could not load %s from manual installation path %s. Trying the \
         autogen path %s...\n"
        name manual_install_path autogen_path ;
      let base_path = base_path autogen_path in
      match%bind With_components.load load ~base_path with
      | Ok x ->
          Core.printf "Loaded %s from autogen path %s\n" name autogen_path ;
          return x
      | Error _e ->
          Core.printf
            "Could not load %s from autogen path %s. Autogenerating...\n" name
            autogen_path ;
          let%bind () = Unix.mkdir ~p:() autogen_path in
          With_components.store load ~base_path ~env:(create_env input) )
