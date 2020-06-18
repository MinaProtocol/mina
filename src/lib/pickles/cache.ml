open Core

module Step = struct
  module Key = struct
    module Proving = struct
      type t =
        Type_equal.Id.Uid.t
        * int
        * Backend.Tick.R1CS_constraint_system.t

      let to_string : t -> _ = function
        | _id, _n, h ->
            sprintf !"step-%s"
              (Md5.to_hex
                 (Backend.Tick.R1CS_constraint_system.digest h))
    end

    module Verification = struct
      type t = Type_equal.Id.Uid.t * int * Md5.t

      let to_string : t -> _ = function
        | _id, _n, h ->
            sprintf !"vk-step-%s" (Md5.to_hex h)
    end
  end

  let storable =
    Key_cache.Disk_storable.simple Key.Proving.to_string
      (fun (_, _, t) ~path ->
        Snarky_bn382.Fp_index.read
          (Backend.Tick.Keypair.load_urs ())
          t.m.a t.m.b t.m.c
          (Unsigned.Size_t.of_int (1 + t.public_input_size))
          path )
      Snarky_bn382.Fp_index.write

  let vk_storable =
    Key_cache.Disk_storable.simple Key.Verification.to_string
      (fun _ ~path -> Snarky_bn382.Fp_verifier_index.read path)
      Snarky_bn382.Fp_verifier_index.write

  let read_or_generate cache k_p k_v typ main =
    let s_p = storable in
    let s_v = vk_storable in
    let open Async in
    let open Impls.Pairing_based in
    let pk =
      lazy
        ( match%bind
            Common.time "step keypair read" (fun () ->
                Key_cache.read cache s_p (Lazy.force k_p) )
          with
        | Ok (pk, dirty) ->
            Common.time "step keypair create" (fun () ->
                return
                  ( Keypair.create ~pk
                      ~vk:(Backend.Tick.Keypair.vk pk)
                  , dirty ) )
        | Error _e ->
            Timer.clock __LOC__ ;
            let r = generate_keypair ~exposing:[typ] main in
            Timer.clock __LOC__ ;
            let%map _ =
              Key_cache.write cache s_p (Lazy.force k_p) (Keypair.pk r)
            in
            (r, `Generated_something) )
    in
    let vk =
      let k_v = Lazy.force k_v in
      lazy
        ( match%bind
            Common.time "step vk read" (fun () -> Key_cache.read cache s_v k_v)
          with
        | Ok (vk, _) ->
            return vk
        | Error _e ->
            let%bind vk = Lazy.force pk >>| fst >>| Keypair.vk in
            let%map _ = Key_cache.write cache s_v k_v vk in
            vk )
    in
    let run t =
      lazy (Async.Thread_safe.block_on_async_exn (fun () -> Lazy.force t))
    in
    (run pk, run vk)
end

module Wrap = struct
  module Key = struct
    module Verification = struct
      type t = Type_equal.Id.Uid.t * Md5.t [@@deriving sexp, eq]

      let to_string : t -> _ = function
        | _id, h ->
            sprintf !"vk-wrap-%s" (Md5.to_hex h)
    end

    module Proving = struct
      type t =
        Type_equal.Id.Uid.t * Backend.Tock.R1CS_constraint_system.t

      let to_string : t -> _ = function
        | _id, h ->
            sprintf !"wrap-%s"
              (Md5.to_hex
                 (Backend.Tock.R1CS_constraint_system.digest h))
    end
  end

  let storable =
    Key_cache.Disk_storable.simple Key.Proving.to_string
      (fun (_, t) ~path ->
        Snarky_bn382.Fq_index.read
          (Backend.Tock.Keypair.load_urs ())
          t.m.a t.m.b t.m.c
          (Unsigned.Size_t.of_int (1 + t.public_input_size))
          path )
      Snarky_bn382.Fq_index.write

  let vk_storable =
    Key_cache.Disk_storable.simple Key.Verification.to_string
      (fun _ ~path ->
        Snarky_bn382.Fq_verifier_index.read
          (Backend.Tock.Keypair.load_urs ())
          path )
      Snarky_bn382.Fq_verifier_index.write

  let read_or_generate step_domains cache k_p k_v typ main =
    let module Vk = Verification_key in
    let open Async in
    let open Impls.Dlog_based in
    let s_p = storable in
    let pk =
      lazy
        (let k = Lazy.force k_p in
         match%bind Key_cache.read cache s_p k with
         | Ok (pk, d) ->
             return
               ( Keypair.create ~pk ~vk:(Backend.Tock.Keypair.vk pk)
               , d )
         | Error _e ->
             let r = generate_keypair ~exposing:[typ] main in
             let%map _ = Key_cache.write cache s_p k (Keypair.pk r) in
             (r, `Generated_something))
    in
    let vk =
      let k_v = Lazy.force k_v in
      let s_v =
        Key_cache.Disk_storable.of_binable Key.Verification.to_string
          (module Vk)
      in
      lazy
        ( match%bind Key_cache.read cache s_v k_v with
        | Ok (vk, _) ->
            return vk
        | Error _e ->
            let%bind kp, _dirty = Lazy.force pk in
            let vk = Keypair.vk kp in
            let pk = Keypair.pk kp in
            let vk : Vk.t =
              { index= vk
              ; commitments= Backend.Tock.Keypair.vk_commitments vk
              ; step_domains
              ; data=
                  (let open Snarky_bn382.Fq_index in
                  let n = Unsigned.Size_t.to_int in
                  let variables = n (num_variables pk) in
                  { public_inputs= n (public_inputs pk)
                  ; variables
                  ; constraints= variables
                  ; nonzero_entries= n (nonzero_entries pk)
                  ; max_degree= n (max_degree pk) }) }
            in
            let%map _ = Key_cache.write cache s_v k_v vk in
            vk )
    in
    let run t =
      lazy (Async.Thread_safe.block_on_async_exn (fun () -> Lazy.force t))
    in
    (run pk, run vk)
end
