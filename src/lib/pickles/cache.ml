open Core

module Step = struct
  module Key = struct
    module Proving = struct
      type t =
        Type_equal.Id.Uid.t
        * int
        * Zexe_backend.Pairing_based.R1CS_constraint_system.t

      let to_string : t -> _ = function
        | _id, _n, h ->
            sprintf !"step-%s"
              (Md5.to_hex
                 (Zexe_backend.Pairing_based.R1CS_constraint_system.digest h))
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
          (Zexe_backend.Pairing_based.Keypair.load_urs ())
          t.m.a t.m.b t.m.c
          (Unsigned.Size_t.of_int (1 + t.public_input_size))
          path )
      Snarky_bn382.Fp_index.write

  let vk_storable =
    Key_cache.Disk_storable.simple Key.Verification.to_string
      (fun _ ~path -> Snarky_bn382.Fp_verifier_index.read path)
      Snarky_bn382.Fp_verifier_index.write
end

module Wrap = struct
  module Key = struct
    module Verification = struct
      type t = Type_equal.Id.Uid.t * Md5.t [@@deriving sexp]

      let to_string : t -> _ = function
        | _id, h ->
            sprintf !"vk-wrap-%s" (Md5.to_hex h)
    end

    module Proving = struct
      type t =
        Type_equal.Id.Uid.t * Zexe_backend.Dlog_based.R1CS_constraint_system.t

      let to_string : t -> _ = function
        | _id, h ->
            sprintf !"wrap-%s"
              (Md5.to_hex
                 (Zexe_backend.Dlog_based.R1CS_constraint_system.digest h))
    end
  end

  let storable =
    Key_cache.Disk_storable.simple Key.Proving.to_string
      (fun (_, t) ~path ->
        Snarky_bn382.Fq_index.read
          (Zexe_backend.Dlog_based.Keypair.load_urs ())
          t.m.a t.m.b t.m.c
          (Unsigned.Size_t.of_int (1 + t.public_input_size))
          path )
      Snarky_bn382.Fq_index.write

  let vk_storable =
    Key_cache.Disk_storable.simple Key.Verification.to_string
      (fun _ ~path ->
        Snarky_bn382.Fq_verifier_index.read
          (Zexe_backend.Dlog_based.Keypair.load_urs ())
          path )
      Snarky_bn382.Fq_verifier_index.write
end
