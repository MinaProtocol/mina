open Marlin_plonk_bindings
let%test_module "TLS Notary test" =
(
    module struct
    let () =
      Zexe_backend.Pasta.Vesta_based_plonk_plookup.Keypair.set_urs_info
        [On_disk {directory= "/tmp/"; should_write= true}]

    (*
      Zk-Snark implemented here allows proving the following:

      Given:
        1. Signature Scheme base EC point
        2. [2^n] multiple of the base point (where n is the bit-size of the base field elements).
          This is needed only for the circuit optimization
        3. TlsNotary public key EC point
      as public inputs,

      Prover knows:
        1. TLS session ciphertext: CT
        2. AES server key computed from TLS session master secret: KEY
        3. AES initialization vector computed from TLS session master secret: IV
        4. TlsNotary signature: (P, S)

      such that:
        1. Having computed AES key schedule KEY -> KS
        2. Having computed GCM hash key KS -> HK
        3. Having decrypted cyphertext into plaintext (CT, KS, IV) -> PT
        4. Having computed cyphertext authentication tag (CT, HK) -> AT
        4. Having hashed the data (KEY, IV, AT, P) -> E
        5. Score value from plaintext PT is above the threshold value
        6. TlsNotary signature (P, S) verifies against:
          a. TlsNotary public key
          b. S, E scalars

      Prover computation for this SNARK includes the complete TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
      TLS cipher GCM-AES functionality
    *)

    module TlsNotarySignature
        (Impl : Snarky.Snark_intf.Run with type prover_state = unit and type field = Pasta_fp.t)
        (Params : sig val params : Impl.field Sponge.Params.t end)
    = struct
      open Core
      open Impl

      let authentication (p, pn, q) () =

        let module Block = Plonk.Bytes.Block (Impl) in
        let module Bytes = Plonk.Bytes.Constraints (Impl) in
        let module Sponge = Plonk.Poseidon.ArithmeticSponge (Impl) (Params) in
        let module Ecc = Plonk.Ecc.Constraints (Impl) in
        let module Ec = Ecc.Basic in

        Random.full_init [|7|];
        (* CIPHERTEXT *)
        let ctl = Array.length Test.ct in
        let blocks = (ctl + 15) / 16 in
        let ct = Array.init ctl ~f:(fun i -> Field.of_int Test.ct.(i)) in
        (* AES SERVER ENCRYPTION KEY *)
        let key = Array.init 16 ~f:(fun i -> Field.of_int Test.key.(i)) in
        (* AES INITIALIZATION VECTOR *)
        let iv = Array.init 16 ~f:(fun i -> Field.of_int Test.iv.(i)) in
        (* TLS NOTARY SIGNATURE *)
        let ((x, y), s) = Test.sign in
        let ((x, y), s) = Bigint.((to_field (of_decimal_string x), to_field (of_decimal_string y)), to_field (of_decimal_string s)) in
        let (rc, s) = Field.((constant x, constant y), constant s) in

        (* compute AES key schedule *)
        let ks = Block.expandKey key in

        (* compute GCM hash key *)
        let h = Block.encryptBlock (Array.init 16 ~f:(fun _ -> Field.zero)) ks in

        (* initialize/encrypt GCM counters *)
        let ec0 = Array.copy iv in
        Array.iteri [|0;0;0;1|] ~f:(fun i x -> ec0.(i+12) <- Field.of_int x);
        let ec0 = Block.encryptBlock ec0 ks in
        let ptdl1 = 2 in
        let ec = Array.init ptdl1 ~f:(fun i -> 
        (
          let cnt = Array.copy iv in
          let i = i + blocks - ptdl1 + 2 in
          Array.iteri Int.[|i lsr 24; (i lsr 16) land 255; (i lsr 8) land 255; i land 255;|]
            ~f:(fun j x -> cnt.(j + 12) <- Field.of_int x);
          Block.encryptBlock cnt ks
        )) in

        (* decrypt score ciphertext into plaintext and decode *)
        let score = let offset = ctl-9-(blocks-ptdl1)*16 in Array.mapi (Array.sub ct (ctl-9) 3)
          ~f:(fun i x -> Bytes.asciiDigit (Bytes.xor ec.((offset+i)/16).((offset+i)%16) x)) in
        
        (* check the score *)
        Bytes.assertScore Field.(score.(0) * (of_int 100) + score.(1) * (of_int 10) + score.(2));

        (* pad ciphertext to the block boundary *)
        let ctp = Array.append ct (Array.init (blocks*16-ctl) ~f:(fun _ -> Field.zero)) in
        
        (* compute GCM ciphertext authentication tag *)
        let rec tag ht ct =
          if Array.length ct <= 0 then ht
          else Block.mul (Block.xor (tag ht (Array.sub ct 0 (Array.length ct - 16))) (Array.sub ct (Array.length ct - 16) 16)) h
        in
        let len = Array.init 16 ~f:(fun _ -> Field.zero) in
        len.(13) <- Field.of_int (((ctl*8) lsr 16) land 255);
        len.(14) <- Field.of_int (((ctl*8) lsr 8) land 255);
        len.(15) <- Field.of_int ((ctl*8) land 255);
        let at = Block.xor ec0 (tag (Array.init 16 ~f:(fun _ -> Field.zero)) (Array.append ctp len)) in

        (* hash the data to be signed *)
        let hb = Array.map ~f:(fun x -> Bytes.b16tof x) [|key; iv; at|] in
        Array.iter ~f:(fun x -> Sponge.absorb x) (Array.append hb [|fst rc; snd rc;|]);
        let e = Sponge.squeeze in

        (* verify TlsNotary signature *)
        let lpt = Ecc.add (Ecc.mul q e) rc in
        let rpt = Ecc.sub (Ecc.scale_pack p s) pn in
        assert_ (Snarky.Constraint.equal (fst lpt) (fst lpt));
        assert_ (Snarky.Constraint.equal (snd rpt) (snd rpt));
        ()

      module Public_input = Test.Public_input (Impl)
      open Public_input
      let input () = 
        let open Typ in
        Impl.Data_spec.
        [
          tuple3
            (tuple2 Field.typ Field.typ)  (* signature scheme base point P *)
            (tuple2 Field.typ Field.typ)  (* [n]P where n = field elements size in bits *)
            (tuple2 Field.typ Field.typ)  (* notary public key *)
        ]

      let keys = Impl.generate_keypair ~exposing:(input ()) authentication
      let proof = Impl.prove (Impl.Keypair.pk keys) (input ()) authentication () public_input
      let%test_unit "check backend GcmAuthentication proof" =
        assert (Impl.verify proof (Impl.Keypair.vk keys) (input ()) public_input)
    end

    module Impl = Snarky.Snark.Run.Make(Zexe_backend.Pasta.Vesta_based_plonk_plookup) (Core.Unit)
    module Params = struct let params = Sponge.Params.(map pasta_p5 ~f:Impl.Field.Constant.of_string) end
    include TlsNotarySignature (Impl) (Params) 
  end
)
