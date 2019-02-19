[%%import
"../../../config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Signature_lib
open Core

module Blockchain_snark_keys = struct
  module Proving = struct
    let load_expr ~loc bc_location bc_checksum =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      [%expr
        let open Async.Deferred in
        Blockchain_snark.Blockchain_transition.Keys.Proving.load
          (Blockchain_snark.Blockchain_transition.Keys.Proving.Location
           .of_string
             [%e
               estring
                 (Blockchain_snark.Blockchain_transition.Keys.Proving.Location
                  .to_string bc_location)])
        >>| fun (keys, checksum) ->
        assert (
          String.equal (Md5_lib.to_hex checksum)
            [%e estring (Md5_lib.to_hex bc_checksum)] ) ;
        keys]
  end

  module Verification = struct
    let load_expr ~loc bc_location bc_checksum =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      [%expr
        let open Async.Deferred in
        Blockchain_snark.Blockchain_transition.Keys.Verification.load
          (Blockchain_snark.Blockchain_transition.Keys.Verification.Location
           .of_string
             [%e
               estring
                 (Blockchain_snark.Blockchain_transition.Keys.Verification
                  .Location
                  .to_string bc_location)])
        >>| fun (keys, checksum) ->
        assert (
          String.equal (Md5_lib.to_hex checksum)
            [%e estring (Md5_lib.to_hex bc_checksum)] ) ;
        keys]
  end
end

module Transaction_snark_keys = struct
  module Proving = struct
    let load_expr ~loc t_location t_checksum =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      [%expr
        let open Async.Deferred in
        Transaction_snark.Keys.Proving.load
          (Transaction_snark.Keys.Proving.Location.of_string
             [%e
               estring
                 (Transaction_snark.Keys.Proving.Location.to_string t_location)])
        >>| fun (keys, checksum) ->
        assert (
          String.equal (Md5_lib.to_hex checksum)
            [%e estring (Md5_lib.to_hex t_checksum)] ) ;
        keys]
  end

  module Verification = struct
    let load_expr ~loc t_location t_checksum =
      let module E = Ppxlib.Ast_builder.Make (struct
        let loc = loc
      end) in
      let open E in
      [%expr
        let open Async.Deferred in
        Transaction_snark.Keys.Verification.load
          (Transaction_snark.Keys.Verification.Location.of_string
             [%e
               estring
                 (Transaction_snark.Keys.Verification.Location.to_string
                    t_location)])
        >>| fun (keys, checksum) ->
        assert (
          String.equal (Md5_lib.to_hex checksum)
            [%e estring (Md5_lib.to_hex t_checksum)] ) ;
        keys]
  end
end

let ok_or_fail_expr ~loc =
  [%expr function Ok x -> x | Error _ -> failwith "Gen_keys error"]

module Dummy = struct
  module Transaction_keys = struct
    module Proving = struct
      let expr ~loc = [%expr Async.return Transaction_snark.Keys.Proving.dummy]
    end

    module Verification = struct
      let expr ~loc =
        [%expr Async.return Transaction_snark.Keys.Verification.dummy]
    end
  end

  module Blockchain_keys = struct
    module Proving = struct
      let expr ~loc =
        [%expr
          Async.return
            Blockchain_snark.Blockchain_transition.Keys.Proving.dummy]
    end

    module Verification = struct
      let expr ~loc =
        [%expr
          Async.return
            Blockchain_snark.Blockchain_transition.Keys.Verification.dummy]
    end
  end
end

open Async

let loc = Ppxlib.Location.none

[%%if
proof_level <> "none"]

let gen_keys () =
  let%bind tx_keys_location, tx_keys, tx_keys_checksum =
    Transaction_snark.Keys.cached ()
  in
  let module M =
    (* TODO make toplevel library to encapsulate consensus params *)
      Blockchain_snark.Blockchain_transition.Make
        (Consensus)
        (Transaction_snark.Verification.Make (struct
          let keys = tx_keys
        end))
  in
  let%map bc_keys_location, _bc_keys, bc_keys_checksum = M.Keys.cached () in
  ( Blockchain_snark_keys.Proving.load_expr ~loc bc_keys_location.proving
      bc_keys_checksum.proving
  , Blockchain_snark_keys.Verification.load_expr ~loc
      bc_keys_location.verification bc_keys_checksum.verification
  , Transaction_snark_keys.Proving.load_expr ~loc tx_keys_location.proving
      tx_keys_checksum.proving
  , Transaction_snark_keys.Verification.load_expr ~loc
      tx_keys_location.verification tx_keys_checksum.verification )

[%%else]

let gen_keys () =
  return
    ( Dummy.Blockchain_keys.Proving.expr ~loc
    , Dummy.Blockchain_keys.Verification.expr ~loc
    , Dummy.Transaction_keys.Proving.expr ~loc
    , Dummy.Transaction_keys.Verification.expr ~loc )

[%%endif]

let main () =
  (*   let%bind blockchain_expr, transaction_expr = *)
  let%bind bc_proving, bc_verification, tx_proving, tx_verification =
    gen_keys ()
  in
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "snark_keys.ml")
  in
  Pprintast.top_phrase fmt
    (Ptop_def
       [%str
         let blockchain_proving () = [%e bc_proving]

         let blockchain_verification () = [%e bc_verification]

         let transaction_proving () = [%e tx_proving]

         let transaction_verification () = [%e tx_verification]]) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
