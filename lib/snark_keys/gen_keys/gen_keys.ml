open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core

let load_transaction_snark_keys_expr
      ~loc
      tx_keys_location
      tx_keys_checksum
  =
  let module E = Ppxlib.Ast_builder.Make(struct let loc = loc end) in
  let open E in
  [%expr
    let open Async.Deferred in
    Transaction_snark.Keys.load
      (Transaction_snark.Keys.Location.of_string
          [%e estring (Transaction_snark.Keys.Location.to_string tx_keys_location)])
    >>| fun (keys, checksum) ->
    assert (String.equal (Md5_lib.to_hex checksum)
              [%e estring (Md5_lib.to_hex tx_keys_checksum)]);
    keys
  ]
;;

let load_blockchain_snark_keys_expr
      ~loc
      bc_keys_location
      bc_keys_checksum
  =
  let module E = Ppxlib.Ast_builder.Make(struct let loc = loc end) in
  let open E in
  [%expr
    let open Async.Deferred in
    Blockchain_snark.Blockchain_transition.Keys.load
      (Blockchain_snark.Blockchain_transition.Keys.Location.of_string
         [%e estring (Blockchain_snark.Blockchain_transition.Keys.Location.to_string bc_keys_location)])
    >>| fun (keys, checksum) ->
    assert (String.equal (Md5_lib.to_hex checksum)
              [%e estring (Md5_lib.to_hex bc_keys_checksum)]);
    keys
  ]
;;

let ok_or_fail_expr ~loc =
  [%expr
    function
    | Ok x -> x
    | Error _ -> failwith "Gen_keys error" ]

module Dummy = struct
  module Transaction_keys = struct
    let expr ~loc =
      [%expr Async.return Transaction_snark.Keys.dummy ]
  end

  module Blockchain_keys = struct
    let expr ~loc =
      [%expr Async.return Blockchain_snark.Blockchain_transition.Keys.dummy]
  end
end

open Async

let main () =
  let loc = Ppxlib.Location.none in
  let%bind blockchain_expr, transaction_expr =
    match Nanobit_base.Insecure.key_generation with
    | true ->
      return
        ( Dummy.Blockchain_keys.expr ~loc
        , Dummy.Transaction_keys.expr ~loc
        )
    | false ->
      let%bind (tx_keys_location, tx_keys, tx_keys_checksum)  =
        Transaction_snark.Keys.cached ()
      in
      let module M = Blockchain_snark.Blockchain_transition.Make(
        Transaction_snark.Verification.Make(struct let keys = tx_keys end))
      in
      let%map (bc_keys_location, _bc_keys, bc_keys_checksum) = M.Keys.cached () in
      ( load_blockchain_snark_keys_expr ~loc bc_keys_location bc_keys_checksum
      , load_transaction_snark_keys_expr ~loc tx_keys_location tx_keys_checksum
      )
  in
  let fmt = Format.formatter_of_out_channel (Out_channel.create "snark_keys.ml") in
  Pprintast.top_phrase fmt
    (Ptop_def
      [%str
        open Core

     let blockchain () = [%e blockchain_expr]

     let transaction () = [%e transaction_expr]
      ]);
  exit 0
;;

let () =
  ignore (main ());
  never_returns (Scheduler.go ())
