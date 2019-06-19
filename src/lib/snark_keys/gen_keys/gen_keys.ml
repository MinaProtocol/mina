[%%import
"../../../config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Signature_lib
open Core
open Coda_state

let () =
  let bin_io_id m = Fn.compose (Binable.of_string m) (Binable.to_string m) in
  Core.printf !"gen keys without the files\n%!" ;
  let tx = Transaction_snark.Keys.create () in
  let tx_vk =
    tx.Transaction_snark.Keys.verification
    |> bin_io_id (module Transaction_snark.Keys.Verification)
  in
  let _tx_wrap_vk = tx.Transaction_snark.Keys.verification.wrap in
  let module B =
  Blockchain_snark.Blockchain_transition.Make (Transaction_snark.Verification
                                               .Make
                                                 (struct
    let keys = tx_vk
  end)) in
  let bc_pk_bin_io, bc_vk_bin_io, bc_keys =
    let bc_keys =
      Snark_params.Tick.generate_keypair
        (B.Step_base.main (Logger.null ()))
        ~exposing:(B.Step_base.input ())
    in
    let bc_pk =
      Snark_params.Tick.Keypair.pk bc_keys
      |> bin_io_id (module Snark_params.Tick.Proving_key)
    in
    let bc_vk =
      Snark_params.Tick.Keypair.vk bc_keys
      |> bin_io_id (module Snark_params.Tick.Verification_key)
    in
    (bc_pk, bc_vk, bc_keys)
  in
  assert (
    Snark_params.Tick.Proving_key.equal bc_pk_bin_io
      (Snark_params.Tick.Keypair.pk bc_keys) ) ;
  assert (
    Snark_params.Tick.Verification_key.equal bc_vk_bin_io
      (Snark_params.Tick.Keypair.vk bc_keys) ) ;
  let module Step = B.Step (struct
    let keys = bc_keys
  end) in
  let module Wrap_base = B.Wrap_base (struct
    let verification_key = bc_vk_bin_io
  end) in
  let wrap_pk_bin_io, wrap_vk_bin_io, wrap_keys =
    let wrap_keys =
      Snark_params.Tock.generate_keypair ~exposing:Wrap_base.input
        Wrap_base.main
    in
    let pk =
      Snark_params.Tock.Keypair.pk wrap_keys
      |> bin_io_id (module Snark_params.Tock.Proving_key)
    in
    let vk =
      Snark_params.Tock.Keypair.vk wrap_keys
      |> bin_io_id (module Snark_params.Tock.Verification_key)
    in
    (pk, vk, wrap_keys)
  in
  let wrap_pk = Snark_params.Tock.Keypair.pk wrap_keys in
  let wrap_vk = Snark_params.Tock.Keypair.vk wrap_keys in
  let module Wrap =
    B.Wrap (struct
        let verification_key = bc_vk_bin_io
      end)
      (struct
        let keys = wrap_keys
      end)
  in
  let wrap hash proof =
    let open Snark_params in
    let module Wrap = Wrap in
    let input = Wrap_input.of_tick_field hash in
    let hash' = Wrap_input.to_tick_field input in
    Core.printf !"input typ\n%!" ;
    assert (Tick0.Field.equal hash hash') ;
    Core.printf !"assert proving key equality before prove\n%!" ;
    assert (Snark_params.Tock.Proving_key.equal wrap_pk_bin_io wrap_pk) ;
    Core.printf
      !"Constraint system of bin_io-ed version before prove: %s\n %!"
      ( Yojson.Safe.pretty_to_string
      @@ Snark_params.Tock.R1CS_constraint_system.to_json
           (Snark_params.Tock.Proving_key.r1cs_constraint_system wrap_pk_bin_io)
      ) ;
    Core.printf
      !"Constraint system of non-bin_io-ed version before prove: %s\n %!"
      ( Yojson.Safe.pretty_to_string
      @@ Snark_params.Tock.R1CS_constraint_system.to_json
           (Snark_params.Tock.Proving_key.r1cs_constraint_system wrap_pk) ) ;
    let proof1 =
      Tock.prove wrap_pk_bin_io Wrap.input {Wrap.Prover_state.proof} Wrap.main
        input
    in
    let proof2 =
      Tock.prove wrap_pk Wrap.input {Wrap.Prover_state.proof} Wrap.main input
    in
    Core.printf
      !"Constraint system of bin_io-ed version: %s\n %!"
      ( Yojson.Safe.pretty_to_string
      @@ Snark_params.Tock.R1CS_constraint_system.to_json
           (Snark_params.Tock.Proving_key.r1cs_constraint_system wrap_pk_bin_io)
      ) ;
    Core.printf
      !"Constraint system of non-bin_io-ed version: %s\n %!"
      ( Yojson.Safe.pretty_to_string
      @@ Snark_params.Tock.R1CS_constraint_system.to_json
           (Snark_params.Tock.Proving_key.r1cs_constraint_system wrap_pk) ) ;
    Core.printf !"assert verification key equality after prove\n%!" ;
    assert (Snark_params.Tock.Verification_key.equal wrap_vk_bin_io wrap_vk) ;
    Core.printf !"assert proving key equality after prove\n%!" ;
    assert (Snark_params.Tock.Proving_key.equal wrap_pk_bin_io wrap_pk) ;
    Core.printf !"verify wrap proof\n%!" ;
    assert (Tock.verify proof2 wrap_vk Wrap.input input) ;
    assert (Tock.verify proof1 wrap_vk_bin_io Wrap.input input) ;
    assert (1 = 0) ;
    proof
  in
  let step_main x = Step.main (Logger.create ()) x in
  let instance_hash =
    let open Coda_base in
    let s =
      let wrap_vk = Snark_params.Tock.Keypair.vk Wrap.keys in
      Snark_params.Tick.Pedersen.State.update_fold
        Hash_prefix.transition_system_snark
        Fold_lib.Fold.(
          Snark_params.tock_vk_to_bool_list wrap_vk
          |> of_list |> group3 ~default:false)
    in
    fun state ->
      Snark_params.Tick.Pedersen.digest_fold s
        (State_hash.fold (Protocol_state.hash state))
  in
  let base_hash = instance_hash Genesis_protocol_state.t.data in
  let () =
    let open Snark_params in
    let prover_state =
      { Step.Prover_state.prev_proof= Tock.Proof.dummy
      ; wrap_vk= Tock.Keypair.vk Wrap.keys
      ; prev_state= Protocol_state.negative_one
      ; expected_next_state= None
      ; update= Snark_transition.genesis }
    in
    let main x =
      Tick.handle (step_main x) Consensus.Data.Prover_state.precomputed_handler
    in
    let tick =
      Tick.prove
        (Tick.Keypair.pk Step.keys)
        (Step.input ()) prover_state main base_hash
    in
    assert (
      Tick.verify tick (Tick.Keypair.vk Step.keys) (Step.input ()) base_hash ) ;
    let _proof = wrap base_hash tick in
    ()
  in
  assert (1 = 0)

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
proof_level = "full"]

let gen_keys () =
  let%bind tx_keys_location, tx_keys, tx_keys_checksum =
    Transaction_snark.Keys.cached ()
  in
  let module M =
  (* TODO make toplevel library to encapsulate consensus params *)
  Blockchain_snark.Blockchain_transition.Make (Transaction_snark.Verification
                                               .Make
                                                 (struct
    let keys = tx_keys
  end)) in
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
