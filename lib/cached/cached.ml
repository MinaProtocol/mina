open Core
open Async

type 'a value = {path: string; value: 'a; checksum: Md5.t}

module Projection = struct
  type 'a t =
    | T : string * ('a -> 's) * 's Storage.Disk.Controller.t -> 'a t
end

module T = struct
  module Env = struct
    type 'e t =
      { base_path : string
      ; value : 'e Lazy.t
      }
  end

  type ('a, 'e) t = 'e Env.t -> 'a Deferred.t

  let bind t ~f =
    fun e ->
      Deferred.bind (t e) ~f:(fun x ->
        (f x) e)

  let return x = fun _ -> return x

  let map = `Define_using_bind
end
include T
include Monad.Make2(T)

type ('a, 'e) cached = ('a, 'e) t

let base_path : (string, _) t = fun { base_path; _} -> Deferred.return base_path

let lift_deferred dx = fun _ -> dx

let get_env : ('e Lazy.t, 'e) t = fun { value; _} -> Deferred.return value

let component ~label ~f bin_t =
  let open Storage.Disk in
  let open Let_syntax in
  let%bind base_path = base_path in
  let path = base_path ^ "_" ^ label in
  let controller = Storage.Disk.Controller.create ~parent_log:(Logger.create ()) bin_t in
  match%bind lift_deferred (load_with_checksum controller path) with
  | Error `Checksum_no_match ->
    failwith "Checksum failure"
  | Error ((`IO_error _ | `No_exist) as err) ->
      ( match err with
      | `IO_error e ->
          Core.printf "Cached error: %s\n%!" (Error.to_string_hum e)
      | `No_exist -> Core.printf "Not found\n%!" ) ;
      let%bind env = get_env in
      let value = f (Lazy.force env) in
      let%map checksum = lift_deferred (store_with_checksum controller path value) in
      {path; value; checksum}
  | Ok {data; checksum} ->
      Core.printf "All ok!\n%!" ;
      return {path; value= data; checksum}
;;

module Spec = struct
  type 'a t =
    | T :
    { load:('a, 'env) cached
    ; directory:string
    ; digest_input:('input -> string)
    ; create_env:('input -> 'env)
    ; input:'input
    }
    -> 'a t

  let create ~load ~directory ~digest_input ~create_env ~input =
    T { load; directory; digest_input; create_env; input }
end

let run (Spec.T { load; directory; digest_input; create_env; input }) =
  let open Deferred.Let_syntax in
  let%bind () = Unix.mkdir ~p:() directory in
  let hash = digest_input input in
  let base_path = directory ^/ hash in
  let env = { Env.base_path; value = lazy (create_env input) } in
  load env
