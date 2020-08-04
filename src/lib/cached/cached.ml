open Core
open Async

type 'a value = {path: string; value: 'a; checksum: Md5.t}

let try_load bin path =
  let logger = Logger.create () in
  let controller = Storage.Disk.Controller.create ~logger bin in
  match%map Storage.Disk.load_with_checksum controller path with
  | Ok {Storage.Checked_data.data; checksum} ->
      [%log trace]
        ~metadata:[("path", `String path)]
        "Loaded value successfully from $path" ;
      Ok {path; value= data; checksum}
  | Error `Checksum_no_match ->
      Or_error.error_string "Checksum failure"
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
        ; bin: 'a Binable.m }
        -> ('a value, 'env) t

  let path (Load {label; f= _; bin= _}) ~base_path = base_path ^ "_" ^ label

  let load (Load {label= _; f= _; bin} as l) ~base_path =
    try_load bin (path ~base_path l)

  let store (Load {label= _; f; bin} as l) ~base_path ~env =
    let path = path ~base_path l in
    let logger = Logger.create () in
    let controller = Storage.Disk.Controller.create ~logger bin in
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
      | Pure x ->
          Pure (f x)
      | Ap (c, t1) ->
          Ap (c, map t1 ~f:(fun g x -> f (g x)))

    let rec apply : type a b e. (a -> b, e) t -> (a, e) t -> (b, e) t =
     fun t1 t2 ->
      match (t1, t2) with
      | Pure f, y ->
          map ~f y
      | Ap (x, y), z ->
          Ap (x, apply (map y ~f:Fn.flip) z)

    let map = `Define_using_apply
  end

  include T
  include Applicative.Make2 (T)

  let rec load : type a e.
      (a, e) t -> base_path:string -> a Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    fun t ~base_path ->
      match t with
      | Pure x ->
          return x
      | Ap ((Load _ as c), tf) ->
          let%map x = Component.load c ~base_path and f = load tf ~base_path in
          f x

  let rec path : type a e. (a, e) t -> base_path:string -> string list =
   fun t ~base_path ->
    match t with
    | Pure _ ->
        []
    | Ap ((Load _ as c), tf) ->
        Component.path c ~base_path :: path tf ~base_path

  let rec store : type a e.
      (a, e) t -> base_path:string -> env:e -> a Deferred.t =
    let open Deferred.Let_syntax in
    fun t ~base_path ~env ->
      match t with
      | Pure x ->
          return x
      | Ap ((Load _ as c), tf) ->
          let%bind x = Component.store c ~base_path ~env in
          let%map f = store tf ~base_path ~env in
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

let component ~label ~f bin = Ap (Component.Load {label; f; bin}, Pure Fn.id)

module Spec = struct
  type 'a t =
    | T :
        { load: ('a, 'env) With_components.t
        ; name: string
        ; autogen_path: string
        ; manual_install_path: string
        ; brew_install_path: string
        ; s3_install_path: string
        ; digest_input: 'input -> string
        ; create_env: 'input -> 'env
        ; input: 'input }
        -> 'a t

  let create ~load ~name ~autogen_path ~manual_install_path ~brew_install_path
      ~s3_install_path ~digest_input ~create_env ~input =
    T
      { load
      ; name
      ; autogen_path
      ; manual_install_path
      ; brew_install_path
      ; s3_install_path
      ; digest_input
      ; create_env
      ; input }
end

module Track_generated = struct
  type t = [`Generated_something | `Locally_generated | `Cache_hit]

  let empty = `Cache_hit

  let ( + ) x y =
    match (x, y) with
    | `Generated_something, _ | _, `Generated_something ->
        `Generated_something
    | `Locally_generated, _ | _, `Locally_generated ->
        `Locally_generated
    | `Cache_hit, `Cache_hit ->
        `Cache_hit
end

module With_track_generated = struct
  type 'a t = {data: 'a; dirty: Track_generated.t}
end

(* This is just the writer monad in a deferred *)
module Deferred_with_track_generated = struct
  type 'a t = 'a With_track_generated.t Deferred.t

  include Monad.Make2 (struct
    type nonrec ('a, 'm) t = 'a t

    let return x =
      Deferred.return
        {With_track_generated.data= x; dirty= Track_generated.empty}

    let map = `Define_using_bind

    let bind t ~f =
      let open Deferred.Let_syntax in
      let%bind {With_track_generated.data; dirty= dirty1} = t in
      let%map {With_track_generated.data= output; dirty= dirty2} = f data in
      { With_track_generated.data= output
      ; dirty= Track_generated.(dirty1 + dirty2) }
  end)
end

let run
    (Spec.T
      { load
      ; name
      ; autogen_path
      ; manual_install_path
      ; brew_install_path
      ; s3_install_path
      ; digest_input
      ; create_env
      ; input }) =
  let open Deferred.Let_syntax in
  let hash = digest_input input in
  let s3_bucket_prefix =
    "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net"
  in
  let base_path directory = directory ^/ hash in
  let full_paths directory =
    With_components.path load ~base_path:(base_path directory)
  in
  match%bind
    Deferred.List.fold
      [manual_install_path; brew_install_path; s3_install_path] ~init:None
      ~f:(fun acc path ->
        if is_some acc then return acc
        else
          match%map With_components.load load ~base_path:(base_path path) with
          | Ok x ->
              Core_kernel.printf
                !"Loaded %s from the following paths %{sexp: string list}\n"
                name (full_paths path) ;
              Some x
          | Error e ->
              Core_kernel.printf
                !"Error loading from (name %s) (base_path %s) (full paths \
                  %{sexp: string list}: %s\n"
                name (base_path path) (full_paths path) (Error.to_string_hum e) ;
              None )
  with
  | Some data ->
      return {With_track_generated.data; dirty= `Cache_hit}
  | None -> (
      Core_kernel.printf
        !"Could not load %s from the following paths:\n\
         \ \n\
          %{sexp: string list}\n\
          %{sexp: string list}\n\
          %{sexp: string list}\n\
         \ \n\
         \ Trying s3 http:\n\
         \ %{sexp: string list}...\n"
        name
        (full_paths manual_install_path)
        (full_paths brew_install_path)
        (full_paths s3_install_path)
        (full_paths s3_bucket_prefix) ;
      (* Attempt load from s3 *)
      let open Deferred.Let_syntax in
      let%bind () = Async.Unix.mkdir ~p:() s3_install_path in
      let%bind () = Async.Unix.mkdir ~p:() autogen_path in
      match%bind
        let open Deferred.Result.Let_syntax in
        let%bind () =
          Cache_dir.load_from_s3
            (full_paths s3_bucket_prefix)
            (full_paths s3_install_path)
            ~logger:(Logger.create ())
        in
        With_components.load load ~base_path:(base_path s3_install_path)
      with
      | Ok data ->
          Core_kernel.printf
            !"Successfully loaded keys from s3 and placed them in %{sexp: \
              string list}\n"
            (full_paths s3_install_path) ;
          return {With_track_generated.data; dirty= `Cache_hit}
      | Error e -> (
          Core_kernel.printf "Failed to load keys from s3: %s, looking at %s\n"
            (Error.to_string_hum e) autogen_path ;
          match%bind
            With_components.load load ~base_path:(base_path autogen_path)
          with
          | Ok data ->
              Core_kernel.printf
                !"Loaded %s from autogen path %{sexp: string list}\n"
                name (full_paths autogen_path) ;
              (* We consider this a "cache miss" for the purposes of tracking
               * that we need to push to s3 *)
              return {With_track_generated.data; dirty= `Locally_generated}
          | Error _e ->
              Core_kernel.printf
                !"Could not load %s from autogen path %{sexp: string list}. \
                  Autogenerating...\n"
                name (full_paths autogen_path) ;
              let%bind () = Unix.mkdir ~p:() autogen_path in
              let%map data =
                With_components.store load ~base_path:(base_path autogen_path)
                  ~env:(create_env input)
              in
              {With_track_generated.data; dirty= `Generated_something} ) )
