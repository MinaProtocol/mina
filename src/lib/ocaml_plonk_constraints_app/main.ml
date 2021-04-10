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

      let authentication x () =
        let module Block = Plonk.Bytes.Block (Impl) in
        let module Bytes = Plonk.Bytes.Constraints (Impl) in
        let module Sponge = Plonk.Poseidon.ArithmeticSponge (Impl) (Params) in
        let module Ecc = Plonk.Ecc.Constraints (Impl) in
        let module Ec = Ecc.Basic in

        Random.full_init [|5|];
        let n = Field.size_in_bits in

        (* SIGNATURE SCHEME PARAMETERS EC BASE POINT *)
        let rec ecp () =
        (
          let x = Int64.(Random.int64 max_value) in
          let x = Field.Constant.of_string (Int64.to_string x) in
          if Field.Constant.(is_square (x*x*x + (of_int 5))) = true then x
          else ecp ()
        ) in
        let px = ecp () in
        let py = Field.Constant.(sqrt (px*px*px + (of_int 5))) in
        let rec double (x, y) n = if n < 1 then (x, y) else double (Ec.double1 (x, y)) Int.(n - 1) in
        let pxn, pyn = double (px, py) n in
        let p = (Field.constant px), (Field.constant py) in
        let pn = (Field.constant pxn), (Field.constant (Field.Constant.negate pyn)) in
        (* NOTARY SECRET KEY *)
        let a = Int.(Random.int max_value) in
        (* NOTARY PUBLIC KEY *)
        let q = Ec.mul (px, py) a in
        let qc = (Field.constant (fst q)), (Field.constant (snd q)) in

        (* PLAINTEXT *)
        (*let ptl = 1000 + Random.int 1000 in*)
        let ptl = 1593 in
        let blocks = (ptl + 15 ) / 16 in
        let pt = Array.init ptl ~f:(fun _ -> Field.of_int (Random.int 255)) in
        (* AES ENCRYPTED COUNTERS *)
        let ec = Array.init blocks ~f:(fun _ -> Array.init 16 ~f:(fun _ -> Field.of_int (Random.int 255))) in
        (* GCM HASH TAG *)
        let h = Array.init 16 ~f:(fun _ -> Field.of_int (Random.int 255)) in

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

        (* notary computing the signature *)
        let k = Int.(Random.int max_value) in
        let r = Ec.mul (px, py) k in
        let rc = (Field.constant (fst r)), (Field.constant (snd r)) in
        (* hash the data to be signed *)
        let hb = Array.map ~f:(fun x -> Bytes.b16tof x) (Array.append ec [|at|]) in
        Array.iter ~f:(fun x -> Sponge.absorb x) (Array.append hb [|fst rc; snd rc;|]);
        let e = Sponge.squeeze in
        let s = Field.((of_int k) + (of_int a) * e) in

        (* signature as computed by notary *)
        let sign = (rc, s) in

        (* prover signature verification *)
        let lpt = Ecc.add (Ecc.scale_pack qc e) (fst sign) in
        let rpt = Ecc.scale_pack p (snd sign) in
        assert_ (Snarky.Constraint.equal (fst lpt) (fst rpt));
        assert_ (Snarky.Constraint.equal (snd lpt) (snd rpt));

        ()

      let input () = Impl.Data_spec.[Field.typ]
      let keys = Impl.generate_keypair ~exposing:(input ()) authentication
      let statement = Field.Constant.of_int 97531013579
      let proof = Impl.prove (Impl.Keypair.pk keys) (input ()) authentication () statement
      let%test_unit "check backend GcmAuthentication proof" =
        assert (Impl.verify proof (Impl.Keypair.vk keys) (input ()) statement)
    end

    module ComputationExample
        (Impl : Snarky.Snark_intf.Run with type prover_state = unit and type field = Pasta_fp.t)
        (Params : sig val params : Impl.field Sponge.Params.t end)
    = struct
      open Core
      open Impl

      let computation x () =
        let open Field in

        (***** BIT-WISE OPERATIONS FOR GCM-AES *****)
        let module Bytes = Plonk.Bytes.Constraints (Impl) in

        Random.full_init [|7|];
        let rec add x n = if n < 1 then x else add (Bytes.xor x (Field.of_int (Random.int 255))) Int.(n - 1) in
        let rec mul (x, y) n = if n < 1 then (x, y) else mul (Bytes.mul x y) Int.(n - 1) in

        let y = add (Field.of_int (Random.int 255)) 35537 in
        let a, b = mul (y, (Field.of_int (Random.int 255))) 75359 in

        for i = 0 to 255 do
          let a, b = Bytes.xtimesp (Field.of_int i) in
          let a = Bytes.aesLookup a Plonk.Gcm.sboxInd in
          let a = Bytes.aesLookup a Plonk.Gcm.invsboxInd in
          let a = Bytes.aesLookup a Plonk.Gcm.xtime2sboxInd in
          let a = Bytes.aesLookup a Plonk.Gcm.xtime3sboxInd in
          let a = Bytes.aesLookup a Plonk.Gcm.xtime9Ind in
          let a = Bytes.aesLookup a Plonk.Gcm.xtimebInd in
          let a = Bytes.aesLookup a Plonk.Gcm.xtimedInd in
          let a = Bytes.aesLookup a Plonk.Gcm.xtimeeInd + b +
            Bytes.aesLookup (Field.of_int (i mod 10)) Plonk.Gcm.rconInd in
          assert_ (Snarky.Constraint.equal a a);
        done;

        assert_ (Snarky.Constraint.equal a a);
        assert_ (Snarky.Constraint.equal b b);

        for j = 0 to 35 do

          (***** PACKING *****)

          let module Pack = Plonk.Pack.Constraints (Impl) in
          let bits = Pack.unpack x in
          let scalar = Pack.pack bits in
          assert_ (Snarky.Constraint.equal x scalar);

          (***** POSEIDON PERMUTATION *****)

          let module Sponge = Plonk.Poseidon.ArithmeticSponge (Impl) (Params) in
          Sponge.absorb x;
          let x = Sponge.squeeze in
          assert_ (Snarky.Constraint.equal x x);

          (***** EC ARITHMETIC *****)

          let module Ecc = Plonk.Ecc.Constraints (Impl) in
          Random.full_init [|7|];
          let x = exists (Field.typ) ~compute:As_prover.(fun () ->
            let rec ecp () =
            (
              let x = Field.Constant.of_int (Int.(Random.int max_value)) in
              if Field.Constant.(is_square (x*x*x + (of_int 5))) = true then x
              else ecp ()
            ) in
            ecp ()
          ) in
          let y = sqrt (x*x*x + (Field.of_int 5)) in 

          let rec double (x, y) n = if n < 1 then (x, y) else double (Ecc.double (x, y)) Int.(n - 1) in
          let xd, yd = double (x, y) (Array.length bits) in
          
          let x1, y1 = Ecc.add (Ecc.scale (x, y) bits) (xd, negate yd) in
          assert_ (Snarky.Constraint.equal (y1*y1) (x1*x1*x1 + (Field.of_int 5)));

          let bits = Pack.unpack x in
          let x1, y1 = Ecc.scale (x, y) bits in
          assert_ (Snarky.Constraint.equal (y1*y1) (x1*x1*x1 + (Field.of_int 5)));
          let x2, y2 = Ecc.scale_pack (x, y) x in
          assert_ (Snarky.Constraint.equal (y2*y2) (x2*x2*x2 + (Field.of_int 5)));
          assert_ (Snarky.Constraint.equal x1 x2);
          assert_ (Snarky.Constraint.equal y1 y2);

          let x3, y3 = Ecc.scale_pack (x2, y2) y in
          assert_ (Snarky.Constraint.equal (y3*y3) (x3*x3*x3 + (Field.of_int 5)));
          let x4, y4 = Ecc.endoscale (x3, y3) bits in
          assert_ (Snarky.Constraint.equal (y4*y4) (x4*x4*x4 + (Field.of_int 5)));

        done;

        ()

      let input () = Impl.Data_spec.[Field.typ]
      let keys = Impl.generate_keypair ~exposing:(input ()) computation
      let statement = Field.Constant.of_int 97531013579
      let proof = Impl.prove (Impl.Keypair.pk keys) (input ()) computation () statement
      let%test_unit "check backend ComputationExample proof" =
        assert (Impl.verify proof (Impl.Keypair.vk keys) (input ()) statement)
    end

    module Impl = Snarky.Snark.Run.Make(Zexe_backend.Pasta.Vesta_based_plonk_plookup) (Core.Unit)
    module Params = struct let params = Sponge.Params.(map pasta_p5 ~f:Impl.Field.Constant.of_string) end
    include GcmAuthentication (Impl) (Params) 
  end )
