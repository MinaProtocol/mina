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

        Random.full_init [|7|];
        (*let ptl = 1000 + Random.int 1000 in*)
        let ptl = 1592 in
        let blocks = (ptl + 15 ) / 16 in
        let ec = Array.init blocks ~f:(fun _ -> Array.init 16 ~f:(fun _ -> Impl.Field.of_int (Random.int 255))) in
        let h = Array.init 16 ~f:(fun _ -> Impl.Field.of_int (Random.int 255)) in

        let pt = Array.init ptl ~f:(fun _ -> Impl.Field.of_int (Random.int 255)) in

        let module Bytes = Plonk.Bytes.Constraints (Impl) in
        
        let ct = Array.init ptl ~f:(fun i -> Bytes.xor ec.(i/16).(i%16) pt.(i)) in
        let ctp = Array.append ct (Array.init (blocks*16-ptl) ~f:(fun _ -> Impl.Field.zero)) in
        
        let module Block = Plonk.Bytes.Block (Impl) in
        
        let rec tag ht ct =
          if Array.length ct <= 0 then ht
          else Block.mul (Block.xor (tag ht (Array.sub ct 0 (Array.length ct - 16))) (Array.sub ct (Array.length ct - 16) 16)) h
        in

        let ptlb = ptl * 8 in
        let len = Array.init 16 ~f:(fun i -> Impl.Field.of_int ((ptlb lsr (i*8)) land 255)) in
        let ht = tag (Array.init 16 ~f:(fun _ -> Impl.Field.zero)) (Array.append ctp len) in
        let hb = Array.map ~f:(fun x -> Bytes.b16tof x) (Array.append ec [|ht|]) in

        let module Sponge = Plonk.Poseidon.ArithmeticSponge (Impl) (Params) in
        Array.iter ~f:(fun x -> Sponge.absorb x) hb;
        let x = Sponge.squeeze in
        assert_ (Snarky.Constraint.equal x x);

        ()

      let input () = Impl.Data_spec.[Impl.Field.typ]
      let keys = Impl.generate_keypair ~exposing:(input ()) authentication
      let statement = Impl.Field.Constant.of_int 97531013579
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
        let rec add x n = if n < 1 then x else add (Bytes.xor x (Impl.Field.of_int (Random.int 255))) Int.(n - 1) in
        let rec mul (x, y) n = if n < 1 then (x, y) else mul (Bytes.mul x y) Int.(n - 1) in

        let y = add (Impl.Field.of_int (Random.int 255)) 35537 in
        let a, b = mul (y, (Impl.Field.of_int (Random.int 255))) 75359 in

        for i = 0 to 255 do
          let a, b = Bytes.xtimesp (Impl.Field.of_int i) in
          let a = Bytes.aesLookup a Plonk.Gcm.sboxInd in
          let a = Bytes.aesLookup a Plonk.Gcm.invsboxInd in
          let a = Bytes.aesLookup a Plonk.Gcm.xtime2sboxInd in
          let a = Bytes.aesLookup a Plonk.Gcm.xtime3sboxInd in
          let a = Bytes.aesLookup a Plonk.Gcm.xtime9Ind in
          let a = Bytes.aesLookup a Plonk.Gcm.xtimebInd in
          let a = Bytes.aesLookup a Plonk.Gcm.xtimedInd in
          let a = Bytes.aesLookup a Plonk.Gcm.xtimeeInd + b +
            Bytes.aesLookup (Impl.Field.of_int (i mod 10)) Plonk.Gcm.rconInd in
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

          let module Poseidon = Plonk.Poseidon.Constraints (Impl) (Params) in
          let perm = Poseidon.block_cipher [|x; x+one; x-one; square x; square x|] in
          assert_ (Snarky.Constraint.equal perm.(0) perm.(0));

          (***** EC ARITHMETIC *****)

          let module Ecc = Plonk.Ecc.Constraints (Impl) in
          let y = sqrt (x*x*x + (Impl.Field.of_int 5)) in 

          let rec double (x, y) n = if n < 1 then (x, y) else double (Ecc.double (x, y)) Int.(n - 1) in
          let xd, yd = double (x, y) (Array.length bits) in
          
          let x1, y1 = Ecc.add (Ecc.scale (x, y) bits) (xd, negate yd) in
          assert_ (Snarky.Constraint.equal (y1*y1) (x1*x1*x1 + (Impl.Field.of_int 5)));

          let x1, y1 = Ecc.scale (x, y) bits in
          assert_ (Snarky.Constraint.equal (y1*y1) (x1*x1*x1 + (Impl.Field.of_int 5)));
          let x2, y2 = Ecc.scale_pack (x, y) x in
          assert_ (Snarky.Constraint.equal (y2*y2) (x2*x2*x2 + (Impl.Field.of_int 5)));
          assert_ (Snarky.Constraint.equal x1 x2);
          assert_ (Snarky.Constraint.equal y1 y2);

          let x3, y3 = Ecc.scale_pack (x2, y2) y in
          assert_ (Snarky.Constraint.equal (y3*y3) (x3*x3*x3 + (Impl.Field.of_int 5)));
          let x4, y4 = Ecc.endoscale (x3, y3) bits in
          assert_ (Snarky.Constraint.equal (y4*y4) (x4*x4*x4 + (Impl.Field.of_int 5)));

        done;

        ()

      let input () = Impl.Data_spec.[Impl.Field.typ]
      let keys = Impl.generate_keypair ~exposing:(input ()) computation
      let statement = Impl.Field.Constant.of_int 97531013579
      let proof = Impl.prove (Impl.Keypair.pk keys) (input ()) computation () statement
      let%test_unit "check backend ComputationExample proof" =
        assert (Impl.verify proof (Impl.Keypair.vk keys) (input ()) statement)
    end

    module Impl = Snarky.Snark.Run.Make(Zexe_backend.Pasta.Vesta_based_plonk_plookup) (Core.Unit)
    module Params = struct let params = Sponge.Params.(map pasta_p5 ~f:Impl.Field.Constant.of_string) end
    include GcmAuthentication (Impl) (Params) 
  end )
