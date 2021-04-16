(*
  Zk-Snark implemented here allows proving the following:

  Given:
    1. Signature Scheme base EC point
    2. [2^n] multiple of the base point (where n is the bit-size of the base field elements).
       This is needed only for the circuit optimization
    3. TlsNotary public key EC point
  as public inputs,

  Prover knows:
    1. TLS session plaintext: PT
    2. AES counters, as computed by the TlsNotary: EC
    3. GCM hash key, as computed by the TlsNotary: HK
    4. TlsNotary signature: (P, S)

  such that:
    1. Having computed cyphertext (PT, EC ) -> CT
    2. Having computed cyphertext authentications tag (CT, HK) -> AT
    3. TlsNotary signature (P, S) verifies against:
      a. Data: (HK, EC, AT, P) hashed into scalar E
      b. TlsNotary public key
      c. S, E scalars
*)

open Marlin_plonk_bindings
let%test_module "backend test" =
  (
    module struct
    let () =
      Zexe_backend.Pasta.Vesta_based_plonk_plookup.Keypair.set_urs_info
        [On_disk {directory= "/tmp/"; should_write= true}]

    module GcmAuthentication
        (Impl : Snarky.Snark_intf.Run with type prover_state = unit and type field = Pasta_fp.t)
        (Params : sig val params : Impl.field Sponge.Params.t end)
    = struct
      open Core
      open Impl
      open Test

      let authentication (p, pn, q) () =
        let module Block = Plonk.Bytes.Block (Impl) in
        let module Bytes = Plonk.Bytes.Constraints (Impl) in
        let module Sponge = Plonk.Poseidon.ArithmeticSponge (Impl) (Params) in
        let module Ecc = Plonk.Ecc.Constraints (Impl) in
        let module Ec = Ecc.Basic in

        Random.full_init [|7|];
        (* PLAINTEXT *)
        let ptl = Array.length Test.pt in
        let blocks = (ptl + 15 ) / 16 in
        let pt = Array.init ptl ~f:(fun i -> Field.of_int Test.pt.(i)) in

        (* AES ENCRYPTED COUNTERS *)
        let ec = Array.init blocks ~f:(fun i -> Array.init 16 ~f:(fun j -> Field.of_int Test.ec.(i).(j))) in

        (* GCM HASH TAG *)
        let h = Array.init 16 ~f:(fun i -> Field.of_int Test.h.(i)) in

        (* signature as computed by notary *)
        let ((x, y), s) = Test.sign in
        let ((x, y), s) = Bigint.((to_field (of_decimal_string x), to_field (of_decimal_string y)), to_field (of_decimal_string s)) in
        let (rc, s) = Field.((constant x, constant y), constant s) in

        (* encrypt plaintext into the ciphertext *)
        let ct = Array.init ptl ~f:(fun i -> Bytes.xor ec.(i/16).(i%16) pt.(i)) in
        (* pad ciphertext to the block boundary *)
        let ctp = Array.append ct (Array.init (blocks*16-ptl) ~f:(fun _ -> Field.zero)) in
        
        (* compute GCM ciphertext authentication tag *)
        let rec tag ht ct =
          if Array.length ct <= 0 then ht
          else Block.mul (Block.xor (tag ht (Array.sub ct 0 (Array.length ct - 16))) (Array.sub ct (Array.length ct - 16) 16)) h
        in
        let len = Array.init 16 ~f:(fun i -> Field.of_int ((ptl lsr (i*8-3)) land 255)) in
        let at = tag (Array.init 16 ~f:(fun _ -> Field.zero)) (Array.append ctp len) in

        (* hash the data to be signed *)
        let hb = Array.map ~f:(fun x -> Bytes.b16tof x) (Array.concat [[|h|]; ec; [|at|]]) in
        Array.iter ~f:(fun x -> Sponge.absorb x) (Array.append hb [|fst rc; snd rc;|]);
        let e = Sponge.squeeze in

        (* verify TlsNotary signature *)
        let lpt = Ecc.add (Ecc.mul q e) rc in
        let rpt = Ecc.sub (Ecc.scale_pack p s) pn in
        assert_ (Snarky.Constraint.equal (fst lpt) (fst rpt));
        assert_ (Snarky.Constraint.equal (snd lpt) (snd rpt));

        ()

      module Test_vector = Test.Vector (Impl)
      open Test_vector
      let input () = 
        let open Typ in
        Impl.Data_spec.
        [
          tuple3
            (tuple2 Field.typ Field.typ)  (* signature scheme base point P *)
            (tuple2 Field.typ Field.typ)  (* [n]P where n = field elements size in bits*)
            (tuple2 Field.typ Field.typ)  (* notary public key *)
        ]

      let keys = Impl.generate_keypair ~exposing:(input ()) authentication
      let proof = Impl.prove (Impl.Keypair.pk keys) (input ()) authentication () public_input
      let%test_unit "check backend GcmAuthentication proof" =
        assert (Impl.verify proof (Impl.Keypair.vk keys) (input ()) public_input)
    end

    module Impl = Snarky.Snark.Run.Make(Zexe_backend.Pasta.Vesta_based_plonk_plookup) (Core.Unit)
    module Params = struct let params = Sponge.Params.(map pasta_p5 ~f:Impl.Field.Constant.of_string) end
    include GcmAuthentication (Impl) (Params) 
  end )
