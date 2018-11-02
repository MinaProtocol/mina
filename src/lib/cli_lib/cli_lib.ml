open Core
open Signature_lib

let read_hidden_line prompt : Bytes.t Async.Deferred.t =
  let open Unix in
  let open Async_unix in
  let open Async.Deferred.Let_syntax in
  let isatty = isatty stdin in
  let old_termios =
    if isatty then Some (Terminal_io.tcgetattr stdin) else None
  in
  let () =
    if isatty then
      Terminal_io.tcsetattr ~mode:Terminal_io.TCSANOW
        {(Option.value_exn old_termios) with c_echo= false; c_echonl= true}
        stdin
  in
  Writer.write (Lazy.force Writer.stdout) prompt ;
  let%map pwd = Reader.read_line (Lazy.force Reader.stdin) in
  if isatty then
    Terminal_io.tcsetattr ~mode:Terminal_io.TCSANOW
      (Option.value_exn old_termios)
      stdin ;
  match pwd with
  | `Ok pwd -> Bytes.of_string pwd
  | `Eof -> failwith "got EOF while reading password"

let lift (t : 'a Async.Deferred.t) : 'a Async.Deferred.Or_error.t =
  Async.Deferred.map t ~f:(fun x -> Ok x)

let hidden_line_or_env prompt ~env : Bytes.t Async.Deferred.Or_error.t =
  let open Async.Deferred.Or_error.Let_syntax in
  match Sys.getenv env with
  | Some p -> return (Bytes.of_string p)
  | _ -> lift (read_hidden_line prompt)

let read_password_exn prompt =
  hidden_line_or_env prompt ~env:"CODA_PRIVKEY_PASS"

let int16 =
  let max_port = 1 lsl 16 in
  Command.Arg_type.map Command.Param.int ~f:(fun x ->
      if 0 <= x && x < max_port then x
      else failwithf "Port not between 0 and %d" max_port () )

module Key_arg_type (Key : sig
  type t

  val of_base64_exn : string -> t

  val to_base64 : t -> string

  val name : string

  val random : unit -> t
end) =
struct
  let arg_type =
    Command.Arg_type.create (fun s ->
        try Key.of_base64_exn s with e ->
          failwithf
            "Couldn't read %s (Invalid key format) %s -- here's a sample one: \
             %s"
            Key.name
            (Error.to_string_hum (Error.of_exn e))
            (Key.to_base64 (Key.random ()))
            () )
end

let public_key_compressed =
  let module Pk = Key_arg_type (struct
    include Public_key.Compressed

    let name = "public key"

    let random () = Public_key.compress (Keypair.create ()).public_key
  end) in
  Pk.arg_type

let public_key =
  Command.Arg_type.map public_key_compressed ~f:(fun pk ->
      match Public_key.decompress pk with
      | None -> failwith "Invalid key"
      | Some pk' -> pk' )

let peer : Host_and_port.t Command.Arg_type.t =
  Command.Arg_type.create (fun s -> Host_and_port.of_string s)

let txn_fee =
  Command.Arg_type.map Command.Param.string ~f:Currency.Fee.of_string

let txn_amount =
  Command.Arg_type.map Command.Param.string ~f:Currency.Amount.of_string

let txn_nonce =
  let open Coda_base in
  Command.Arg_type.map Command.Param.string ~f:Account.Nonce.of_string

let default_client_port = 8301

let work_selection_val =
  let open Protocols in
  function
  | "seq" -> Coda_pow.Work_selection.Seq
  | "rand" -> Coda_pow.Work_selection.Random
  | _ -> failwith "Invalid work selection"

let work_selection =
  Command.Arg_type.map Command.Param.string ~f:work_selection_val

module Secret_box = Secret_box
module Secret_file = Secret_file
open Async
open Async.Deferred.Let_syntax

(** Writes a keypair to [privkey_path] and [privkey_path ^ ".pub"] using [Secret_file] *)
let write_keypair_exn {Keypair.private_key; public_key; _}
    ~(privkey_path : string) ~(password : Secret_file.password) :
    unit Deferred.t =
  let privkey_bytes =
    Private_key.to_bigstring private_key |> Bigstring.to_bytes
  in
  let pubkey_bytes =
    Public_key.Compressed.to_base64 (Public_key.compress public_key)
    |> Bytes.of_string
  in
  match%bind
    Secret_file.write ~path:privkey_path ~mkdir:true ~plaintext:privkey_bytes
      ~password
  with
  | Ok () ->
      (* The hope is that if [Secret_file.write] succeeded then this ought to
      as well, letting [handle_open] stay inside [Secret_file]. It might not
      if the environment changes underneath us, and we won't have nice errors
      in that case. *)
      let%bind pubkey_f = Writer.open_file (privkey_path ^ ".pub") in
      Writer.write_bytes pubkey_f pubkey_bytes ;
      Writer.close pubkey_f
  | Error e -> raise (Error.to_exn e)

(** Reads a private key from [privkey_path] using [Secret_file] *)
let read_keypair_exn ~(privkey_path : string)
    ~(password : Secret_file.password) : Keypair.t Deferred.t =
  match%bind Secret_file.read ~path:privkey_path ~password with
  | Ok pk_bytes -> (
      let pk =
        try pk_bytes |> Bigstring.of_bytes |> Private_key.of_bigstring_exn
        with exn ->
          failwithf
            "Error parsing decrypted private key file, is your keyfile \
             corrupt? %s"
            (Exn.to_string exn) ()
      in
      try return (Keypair.of_private_key_exn pk) with exn ->
        failwithf
          "Error computing public key from private, is your keyfile corrupt? %s"
          (Exn.to_string exn) () )
  | Error e -> raise (Error.to_exn e)

let read_keypair_exn' path =
  read_keypair_exn ~privkey_path:path
    ~password:(lazy (read_password_exn "Secret key password: "))
