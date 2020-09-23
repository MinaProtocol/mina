open Core

module Step = struct
  module Key = struct
    module Proving = struct
      type t =
        Type_equal.Id.Uid.t * int * Backend.Tick.R1CS_constraint_system.t

      let to_string : t -> _ = function
        | _id, _n, h ->
            sprintf !"step-%s"
              (Md5.to_hex (Backend.Tick.R1CS_constraint_system.digest h))
    end

    module Verification = struct
      type t = Type_equal.Id.Uid.t * int * Md5.t [@@deriving sexp]

      let to_string : t -> _ = function
        | _id, _n, h ->
            sprintf !"vk-step-%s" (Md5.to_hex h)
    end
  end

  let storable =
    Key_cache.Sync.Disk_storable.simple Key.Proving.to_string
      (fun (_, _, t) ~path ->
        let t =
          failwith __LOC__
          (*
          Snarky_bn382.Tweedle.Dum.Field_index.read
            (Backend.Tick.Keypair.load_urs ())
            t.m.a t.m.b t.m.c
            (Unsigned.Size_t.of_int (1 + t.public_input_size))
            path *)
        in
        t )
      (failwith __LOC__ (*       Snarky_bn382.Tweedle.Dum.Field_index.write *))

  let vk_storable =
    Key_cache.Sync.Disk_storable.simple Key.Verification.to_string
      (fun _ ~path ->
        failwith __LOC__
        (*          Snarky_bn382.Fp_verifier_index.read path *) )
      (failwith __LOC__ (*       Snarky_bn382.Fp_verifier_index.write *))

  let vk_storable =
    Key_cache.Sync.Disk_storable.simple Key.Verification.to_string
      (fun _ ~path:_ ->
        failwith __LOC__
        (*
        Snarky_bn382.Tweedle.Dum.Field_verifier_index.read
          (Backend.Tick.Keypair.load_urs ())
          path 
*)
        )
      (failwith __LOC__)

  (*       Snarky_bn382.Tweedle.Dum.Field_verifier_index.write *)

  let read_or_generate cache k_p k_v typ main =
    let s_p = storable in
    let s_v = vk_storable in
    let open Impls.Step in
    let pk =
      lazy
        ( match
            Common.time "step keypair read" (fun () ->
                Key_cache.Sync.read cache s_p (Lazy.force k_p) )
          with
        | Ok (pk, dirty) ->
            Common.time "step keypair create" (fun () ->
                (Keypair.create ~pk ~vk:(Backend.Tick.Keypair.vk pk), dirty) )
        | Error _e ->
            Timer.clock __LOC__ ;
            let r = generate_keypair ~exposing:[typ] main in
            Timer.clock __LOC__ ;
            let _ =
              Key_cache.Sync.write cache s_p (Lazy.force k_p) (Keypair.pk r)
            in
            (r, `Generated_something) )
    in
    let vk =
      lazy
        (let k_v = Lazy.force k_v in
         match
           Common.time "step vk read" (fun () ->
               Key_cache.Sync.read cache s_v k_v )
         with
         | Ok (vk, _) ->
             (vk, `Cache_hit)
         | Error _e ->
             let pk, c = Lazy.force pk in
             let vk = Keypair.vk pk in
             let _ = Key_cache.Sync.write cache s_v k_v vk in
             (vk, c))
    in
    (pk, vk)
end

module Wrap = struct
  module Key = struct
    module Verification = struct
      type t = Type_equal.Id.Uid.t * Md5.t [@@deriving sexp]

      let equal (_, x1) (_, x2) = Md5.equal x1 x2

      let to_string : t -> _ = function
        | _id, h ->
            sprintf !"vk-wrap-%s" (Md5.to_hex h)
    end

    module Proving = struct
      type t = Type_equal.Id.Uid.t * Backend.Tock.R1CS_constraint_system.t

      let to_string : t -> _ = function
        | _id, h ->
            sprintf !"wrap-%s"
              (Md5.to_hex (Backend.Tock.R1CS_constraint_system.digest h))
    end
  end

  let storable =
    Key_cache.Sync.Disk_storable.simple Key.Proving.to_string
      (fun (_, t) ~path ->
        let t =
          failwith __LOC__
          (*
          Snarky_bn382.Tweedle.Dee.Field_index.read
            (Backend.Tock.Keypair.load_urs ())
            t.m.a t.m.b t.m.c
            (Unsigned.Size_t.of_int (1 + t.public_input_size))
            path
*)
        in
        t )
      (failwith __LOC__)

  (*       Snarky_bn382.Tweedle.Dee.Field_index.write *)

  let vk_storable =
    Key_cache.Sync.Disk_storable.simple Key.Verification.to_string
      (fun _ ~path ->
        Snarky_bn382.Tweedle.Dee.Field_verifier_index.read
          (Backend.Tock.Keypair.load_urs ())
          path )
      Snarky_bn382.Tweedle.Dee.Field_verifier_index.write

  let read_or_generate step_domains cache k_p k_v typ main =
    let module Vk = Verification_key in
    let open Impls.Wrap in
    let s_p = storable in
    let pk =
      lazy
        (let k = Lazy.force k_p in
         match Key_cache.Sync.read cache s_p k with
         | Ok (pk, d) ->
             (Keypair.create ~pk ~vk:(Backend.Tock.Keypair.vk pk), d)
         | Error _e ->
             let r = generate_keypair ~exposing:[typ] main in
             let _ = Key_cache.Sync.write cache s_p k (Keypair.pk r) in
             (r, `Generated_something))
    in
    let vk =
      lazy
        (let k_v = Lazy.force k_v in
         let s_v =
           Key_cache.Sync.Disk_storable.of_binable Key.Verification.to_string
             (module Vk)
         in
         match Key_cache.Sync.read cache s_v k_v with
         | Ok (vk, _) ->
             vk
         | Error _e ->
             let kp, _dirty = Lazy.force pk in
             let vk = Keypair.vk kp in
             let _pk = Keypair.pk kp in
             let vk : Vk.t =
               { index= vk
               ; commitments= Backend.Tock.Keypair.vk_commitments vk
               ; step_domains
               ; data=
                   (let open Snarky_bn382.Tweedle.Dee.Plonk.Field_index in
                   {constraints= failwith __LOC__}) }
             in
             let _ = Key_cache.Sync.write cache s_v k_v vk in
             vk)
    in
    (pk, vk)
end
