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
with_snark]

let gen_keys () =
  let%bind tx_keys_location, tx_keys, tx_keys_checksum =
    Transaction_snark.Keys.cached ()
  in
  let module Consensus_mechanism = Consensus.Proof_of_signature.Make (struct
    module Time = Coda_base.Block_time
    module Proof = Coda_base.Proof
    module Genesis_ledger = Genesis_ledger

    let proposal_interval = Time.Span.of_ms @@ Int64.of_int 5000

    let private_key = None

    module Ledger_builder_diff = Ledger_builder.Make_diff (struct
      open Coda_base
      module Compressed_public_key = Public_key.Compressed

      module Transaction = struct
        include (
          Transaction :
            module type of Transaction
            with module With_valid_signature := Transaction
                                                .With_valid_signature )

        let receiver _ = failwith "stub"

        let sender _ = failwith "stub"

        let fee _ = failwith "stub"

        let compare _ _ = failwith "stub"

        module With_valid_signature = struct
          include Transaction.With_valid_signature

          let compare _ _ = failwith "stub"
        end
      end

      module Ledger_proof = Transaction_snark

      module Completed_work = struct
        include Ledger_builder.Make_completed_work
                  (Compressed_public_key)
                  (Ledger_proof)
                  (Transaction_snark.Statement)

        let check _ _ = failwith "stub"
      end

      module Ledger_hash = struct
        include Ledger_hash.Stable.V1

        let to_bytes = Ledger_hash.to_bytes
      end

      module Ledger_builder_aux_hash = struct
        include Ledger_builder_hash.Aux_hash.Stable.V1

        let of_bytes = Ledger_builder_hash.Aux_hash.of_bytes
      end

      module Ledger_builder_hash = struct
        include Ledger_builder_hash.Stable.V1

        let of_aux_and_ledger_hash = Ledger_builder_hash.of_aux_and_ledger_hash
      end
    end)
  end) in
  let module M =
    (* TODO make toplevel library to encapsulate consensus params *)
      Blockchain_snark.Blockchain_transition.Make
        (Consensus_mechanism)
        (Transaction_snark.Verification.Make (struct
          let keys = tx_keys.verification
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
