open Core_kernel

module Step = struct
  module Key = struct
    module Proving = struct
      type t =
        Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * int
        * Backend.Tick.R1CS_constraint_system.t

      let to_string : t -> _ = function
        | _id, header, n, _h ->
            sprintf !"step-%s-%s-%d-%s" header.kind.type_ header.kind.identifier
              n header.identifying_hash
    end

    module Verification = struct
      type t = Type_equal.Id.Uid.t * Snark_keys_header.t * int * Md5.t
      [@@deriving sexp]

      let to_string : t -> _ = function
        | _id, header, n, _h ->
            sprintf !"vk-step-%s-%s-%d-%s" header.kind.type_
              header.kind.identifier n header.identifying_hash
    end
    [@@warning "-4"]
  end

  type storable =
    (Key.Proving.t, Backend.Tick.Keypair.t) Key_cache.Sync.Disk_storable.t

  type vk_storable =
    ( Key.Verification.t
    , Kimchi_bindings.Protocol.VerifierIndex.Fp.t )
    Key_cache.Sync.Disk_storable.t

  let storable =
    Key_cache.Sync.Disk_storable.simple Key.Proving.to_string
      (fun (_, header, _, cs) ~path ->
        Or_error.try_with_join (fun () ->
            let open Or_error.Let_syntax in
            let%map header_read, index =
              Snark_keys_header.read_with_header
                ~read_data:(fun ~offset ->
                  Kimchi_bindings.Protocol.Index.Fp.read (Some offset)
                    (Backend.Tick.Keypair.load_urs ()) )
                path
            in
            [%test_eq: int] header.header_version header_read.header_version ;
            [%test_eq: Snark_keys_header.Kind.t] header.kind header_read.kind ;
            [%test_eq: Snark_keys_header.Constraint_constants.t]
              header.constraint_constants header_read.constraint_constants ;
            [%test_eq: string] header.constraint_system_hash
              header_read.constraint_system_hash ;
            { Backend.Tick.Keypair.index; cs } ) )
      (fun (_, header, _, _) t path ->
        Or_error.try_with (fun () ->
            Snark_keys_header.write_with_header
              ~expected_max_size_log2:33 (* 8 GB should be enough *)
              ~append_data:
                (Kimchi_bindings.Protocol.Index.Fp.write (Some true)
                   t.Backend.Tick.Keypair.index )
              header path ) )

  let vk_storable =
    Key_cache.Sync.Disk_storable.simple Key.Verification.to_string
      (fun (_, header, _, _) ~path ->
        Or_error.try_with_join (fun () ->
            let open Or_error.Let_syntax in
            let%map header_read, index =
              Snark_keys_header.read_with_header
                ~read_data:(fun ~offset path ->
                  Kimchi_bindings.Protocol.VerifierIndex.Fp.read (Some offset)
                    (Backend.Tick.Keypair.load_urs ())
                    path )
                path
            in
            [%test_eq: int] header.header_version header_read.header_version ;
            [%test_eq: Snark_keys_header.Kind.t] header.kind header_read.kind ;
            [%test_eq: Snark_keys_header.Constraint_constants.t]
              header.constraint_constants header_read.constraint_constants ;
            [%test_eq: string] header.constraint_system_hash
              header_read.constraint_system_hash ;
            index ) )
      (fun (_, header, _, _) x path ->
        Or_error.try_with (fun () ->
            Snark_keys_header.write_with_header
              ~expected_max_size_log2:33 (* 8 GB should be enough *)
              ~append_data:
                (Kimchi_bindings.Protocol.VerifierIndex.Fp.write (Some true) x)
              header path ) )

  let read_or_generate ~prev_challenges cache ?(s_p = storable) k_p
      ?(s_v = vk_storable) k_v =
    let open Impls.Step in
    let pk =
      lazy
        (let%map.Promise k_p = Lazy.force k_p in
         match
           Common.time "step keypair read" (fun () ->
               Key_cache.Sync.read cache s_p k_p )
         with
         | Ok (pk, dirty) ->
             Common.time "step keypair create" (fun () -> (pk, dirty))
         | Error _e ->
             let _, _, _, sys = k_p in
             let r =
               Common.time "stepkeygen" (fun () ->
                   Keypair.generate ~prev_challenges sys )
             in
             Timer.clock __LOC__ ;
             ignore
               ( Key_cache.Sync.write cache s_p k_p (Keypair.pk r)
                 : unit Or_error.t ) ;
             (Keypair.pk r, `Generated_something) )
    in
    let vk =
      lazy
        (let%bind.Promise k_v = Lazy.force k_v in
         match
           Common.time "step vk read" (fun () ->
               Key_cache.Sync.read cache s_v k_v )
         with
         | Ok (vk, _) ->
             Promise.return (vk, `Cache_hit)
         | Error _e ->
             let%map.Promise pk, c = Lazy.force pk in
             let vk = Backend.Tick.Keypair.vk pk in
             ignore (Key_cache.Sync.write cache s_v k_v vk : unit Or_error.t) ;
             (vk, c) )
    in
    (pk, vk)
end

module Wrap = struct
  module Key = struct
    module Verification = struct
      type t = Type_equal.Id.Uid.t * Snark_keys_header.t * Md5.t
      [@@deriving sexp]

      let equal ((_, x1, y1) : t) ((_, x2, y2) : t) =
        [%equal: unit * Md5.t] ((* TODO: *) ignore x1, y1) (ignore x2, y2)

      let to_string : t -> _ = function
        | _id, header, _h ->
            sprintf !"vk-wrap-%s-%s-%s" header.kind.type_ header.kind.identifier
              header.identifying_hash
    end
    [@@warning "-4"]

    module Proving = struct
      type t =
        Type_equal.Id.Uid.t
        * Snark_keys_header.t
        * Backend.Tock.R1CS_constraint_system.t

      let to_string : t -> _ = function
        | _id, header, _h ->
            sprintf !"wrap-%s-%s-%s" header.kind.type_ header.kind.identifier
              header.identifying_hash
    end
  end

  type storable =
    (Key.Proving.t, Backend.Tock.Keypair.t) Key_cache.Sync.Disk_storable.t

  type vk_storable =
    (Key.Verification.t, Verification_key.t) Key_cache.Sync.Disk_storable.t

  let storable =
    Key_cache.Sync.Disk_storable.simple Key.Proving.to_string
      (fun (_, header, cs) ~path ->
        Or_error.try_with_join (fun () ->
            let open Or_error.Let_syntax in
            let%map header_read, index =
              Snark_keys_header.read_with_header
                ~read_data:(fun ~offset ->
                  Kimchi_bindings.Protocol.Index.Fq.read (Some offset)
                    (Backend.Tock.Keypair.load_urs ()) )
                path
            in
            [%test_eq: int] header.header_version header_read.header_version ;
            [%test_eq: Snark_keys_header.Kind.t] header.kind header_read.kind ;
            [%test_eq: Snark_keys_header.Constraint_constants.t]
              header.constraint_constants header_read.constraint_constants ;
            [%test_eq: string] header.constraint_system_hash
              header_read.constraint_system_hash ;
            { Backend.Tock.Keypair.index; cs } ) )
      (fun (_, header, _) t path ->
        Or_error.try_with (fun () ->
            Snark_keys_header.write_with_header
              ~expected_max_size_log2:33 (* 8 GB should be enough *)
              ~append_data:
                (Kimchi_bindings.Protocol.Index.Fq.write (Some true) t.index)
              header path ) )

  let vk_storable =
    Key_cache.Sync.Disk_storable.simple Key.Verification.to_string
      (fun (_, header, _cs) ~path ->
        Or_error.try_with_join (fun () ->
            let open Or_error.Let_syntax in
            let%map header_read, index =
              Snark_keys_header.read_with_header
                ~read_data:(fun ~offset:_ path ->
                  Binable.of_string
                    (module Verification_key.Stable.Latest)
                    (In_channel.read_all path) )
                path
            in
            [%test_eq: int] header.header_version header_read.header_version ;
            [%test_eq: Snark_keys_header.Kind.t] header.kind header_read.kind ;
            [%test_eq: Snark_keys_header.Constraint_constants.t]
              header.constraint_constants header_read.constraint_constants ;
            [%test_eq: string] header.constraint_system_hash
              header_read.constraint_system_hash ;
            index ) )
      (fun (_, header, _) t path ->
        Or_error.try_with (fun () ->
            Snark_keys_header.write_with_header
              ~expected_max_size_log2:33 (* 8 GB should be enough *)
              ~append_data:(fun path ->
                Out_channel.with_file ~append:true path ~f:(fun file ->
                    Out_channel.output_string file
                      (Binable.to_string
                         (module Verification_key.Stable.Latest)
                         t ) ) )
              header path ) )

  let read_or_generate ~prev_challenges cache ?(s_p = storable) k_p
      ?(s_v = vk_storable) k_v =
    let module Vk = Verification_key in
    let open Impls.Wrap in
    let pk =
      lazy
        (let%map.Promise k = Lazy.force k_p in
         match
           Common.time "wrap key read" (fun () ->
               Key_cache.Sync.read cache s_p k )
         with
         | Ok (pk, d) ->
             (pk, d)
         | Error _e ->
             let _, _, sys = k in
             let r =
               Common.time "wrapkeygen" (fun () ->
                   Keypair.generate ~prev_challenges sys )
             in
             ignore
               ( Key_cache.Sync.write cache s_p k (Keypair.pk r)
                 : unit Or_error.t ) ;
             (Keypair.pk r, `Generated_something) )
    in
    let vk =
      lazy
        (let%bind.Promise k_v = Lazy.force k_v in
         match Key_cache.Sync.read cache s_v k_v with
         | Ok (vk, d) ->
             Promise.return (vk, d)
         | Error _e ->
             let%map.Promise pk, _dirty = Lazy.force pk in
             let vk = Backend.Tock.Keypair.vk pk in
             let vk : Vk.t =
               { index = vk
               ; commitments =
                   Kimchi_pasta.Pallas_based_plonk.Keypair.vk_commitments vk
               ; data =
                   (let open Kimchi_bindings.Protocol.Index.Fq in
                   { constraints = domain_d1_size pk.index })
               }
             in
             ignore (Key_cache.Sync.write cache s_v k_v vk : unit Or_error.t) ;
             let _vk = Key_cache.Sync.read cache s_v k_v in
             (vk, `Generated_something) )
    in
    (pk, vk)
end
