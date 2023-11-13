open Async
open Core

type connection = Process.t

type 'a t = connection -> 'a Or_error.t Deferred.t

module M = struct
  type nonrec 'a t = 'a t

  let return x _ = return (Ok x)

  let map = `Custom (fun m ~f c -> m c >>| Or_error.map ~f)

  let bind m ~f c =
    m c >>= function Error _ as e -> Deferred.return e | Ok x -> f x c
end

include Monad.Make (M)

let lift m _ = m

(* Open connection to a Cassandra database using cqlsh executable
   provided. The connection should be configured via ~/.cassandra/cqlshrc
   configuration file. Return the process handle which can the be used to
   send queries to the database. *)
let connect ?executable keyspace =
  let open Deferred.Or_error.Let_syntax in
  let prog =
    Option.merge executable (Sys.getenv "CQLSH") ~f:Fn.const
    |> Option.value ~default:"cqlsh"
  in
  let%map proc = Process.create ~prog ~args:[ "-k"; keyspace ] () in
  Async.printf "Connected to the Cassandra database\n" ;
  proc

let exec ?cqlsh ~keyspace m =
  let open Deferred.Or_error.Monad_infix in
  connect ?executable:cqlsh keyspace >>= m

let read_json_line chan =
  let open Deferred.Let_syntax in
  match%map Reader.read_line chan with
  | `Eof ->
      Or_error.error_string "Cassandra client: broken pipe"
  | `Ok line -> (
      try
        let j = Yojson.Safe.from_string line in
        match Submission.JSON.raw_of_yojson j with
        | Ppx_deriving_yojson_runtime.Result.Ok s ->
            Ok s
        | Ppx_deriving_yojson_runtime.Result.Error e ->
            Or_error.error_string e
      with Yojson.Json_error e -> Or_error.error_string e )

let rec read_json_output acc chan =
  let open Deferred.Or_error.Let_syntax in
  (* skip empty line *)
  let%bind _ = Reader.read_line chan |> Deferred.map ~f:Or_error.return in
  (* [json] header *)
  let%bind _ = Reader.read_line chan |> Deferred.map ~f:Or_error.return in
  (* [json] header *)
  let%bind _ = Reader.read_line chan |> Deferred.map ~f:Or_error.return in
  match%bind read_json_line chan |> Deferred.map ~f:Or_error.return with
  | Ok s ->
      read_json_output (s :: acc) chan
  | Error _ ->
      return (List.rev acc)

let query q conn =
  let open Deferred.Let_syntax in
  let proc_stdin = Process.stdin conn in
  Writer.write_line proc_stdin q ;
  Writer.(write_line @@ Lazy.force stdout) q ;
  let%bind () = Writer.close proc_stdin in
  let%bind () = Writer.flushed proc_stdin in
  match%bind read_json_output [] (Process.stdout conn) with
  | Ok output ->
      return (Ok output)
  | Error e ->
      return (Error e)
