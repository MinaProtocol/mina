[%%import
"/src/config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core

let hashes ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let f (_, x) = estring (Core.Md5.to_hex x) in
  let ts = Transaction_snark.constraint_system_digests () in
  let bs =
    Blockchain_snark.Blockchain_snark_state.constraint_system_digests ()
  in
  elist (List.map ts ~f @ List.map bs ~f)

let from_disk_expr ~loc id =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%expr
    (* TODO: Not sure what to do with cache hit/generated something *)
    let open Async in
    let%map t, _ =
      Pickles.Verification_key.load ~cache:Cache_dir.cache
        (Sexp.of_string_conv_exn
           [%e
             estring
               (Pickles.Verification_key.Id.sexp_of_t id |> Sexp.to_string)]
           Pickles.Verification_key.Id.t_of_sexp)
      >>| Or_error.ok_exn
    in
    t]

let str ~loc ~transaction_snark ~blockchain_snark =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let hashes = hashes ~loc in
  [%str
    open! Core_kernel

    let transaction_verification () = [%e transaction_snark]

    let blockchain_verification () = [%e blockchain_snark]

    type key_hashes = string list [@@deriving to_yojson]

    let key_hashes : key_hashes = [%e hashes]]

let ok_or_fail_expr ~loc =
  [%expr function Ok x -> x | Error _ -> failwith "Gen_keys error"]

open Async

let loc = Ppxlib.Location.none

[%%if
proof_level = "full"]

let str ~loc =
  let module T = Transaction_snark.Make () in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (T) in
  str ~loc
    ~transaction_snark:(Lazy.force (from_disk_expr ~loc T.id))
    ~blockchain_snark:(Lazy.force (from_disk_expr ~loc B.Proof.id))

[%%else]

let str ~loc =
  let e = [%expr Async.Deferred.return Pickles.Verification_key.dummy] in
  str ~loc ~transaction_snark:e ~blockchain_snark:e

[%%endif]

let main () =
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "snark_keys.ml")
  in
  Pprintast.top_phrase fmt (Ptop_def (str ~loc:Location.none)) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
