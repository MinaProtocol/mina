module type Inputs_intf = sig
  open Intf

  val name : string

  module Rounds : Pickles_types.Nat.Intf

  module Gate_vector : T0

  module Urs : sig
    type t

    val read : string -> t

    val write : t -> string -> unit

    val create :
      Unsigned.Size_t.t -> Unsigned.Size_t.t -> Unsigned.Size_t.t -> t
  end

  module Index : sig
    type t

    val delete : t -> unit

    val create :
         Gate_vector.t
      -> Unsigned.Size_t.t
      -> Urs.t
      -> t
  end

  module Curve : sig
    module Affine : sig
      type t
    end
  end

  module Poly_comm : sig
    module Backend : T0

    type t = Curve.Affine.t Plonk_poly_comm.t

    val of_backend : Backend.t -> t
  end

  module Verifier_index : sig
    type t

    val create : Index.t -> t

    val sigma_comm_0 : t -> Poly_comm.Backend.t

    val sigma_comm_1 : t -> Poly_comm.Backend.t

    val sigma_comm_2 : t -> Poly_comm.Backend.t

    val ql_comm : t -> Poly_comm.Backend.t

    val qr_comm : t -> Poly_comm.Backend.t

    val qo_comm : t -> Poly_comm.Backend.t

    val qm_comm : t -> Poly_comm.Backend.t

    val qc_comm : t -> Poly_comm.Backend.t

    val rcm_comm_0 : t -> Poly_comm.Backend.t

    val rcm_comm_1 : t -> Poly_comm.Backend.t

    val rcm_comm_2 : t -> Poly_comm.Backend.t

    val psm_comm : t -> Poly_comm.Backend.t

    val add_comm : t -> Poly_comm.Backend.t

    val mul1_comm : t -> Poly_comm.Backend.t

    val mul2_comm : t -> Poly_comm.Backend.t

    val emul1_comm : t -> Poly_comm.Backend.t

    val emul2_comm : t -> Poly_comm.Backend.t

    val emul3_comm : t -> Poly_comm.Backend.t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Core_kernel
  open Inputs

  type t = Index.t

  let name = sprintf "%s_%d_v2" name (Pickles_types.Nat.to_int Rounds.n)

  let set_urs_info, load_urs =
    let urs_info = Set_once.create () in
    let urs = ref None in
    let degree = 1 lsl Pickles_types.Nat.to_int Rounds.n in
    (* TODO *)
    let public_inputs = Unsigned.Size_t.of_int 0 in
    (* TODO *)
    let size = Unsigned.Size_t.of_int 0 in
    let set_urs_info specs =
      Set_once.set_exn urs_info Lexing.dummy_pos specs
    in
    let load () =
      match !urs with
      | Some urs ->
          urs
      | None ->
          let specs =
            match Set_once.get urs_info with
            | None ->
                failwith "Dlog_based.urs: Info not set"
            | Some t ->
                t
          in
          let store =
            Key_cache.Sync.Disk_storable.simple
              (fun () -> name)
              (fun () ~path -> Urs.read path)
              Urs.write
          in
          let u =
            match Key_cache.Sync.read specs store () with
            | Ok (u, _) ->
                u
            | Error _e ->
                let urs =
                  Urs.create (Unsigned.Size_t.of_int degree) public_inputs size
                in
                let _ =
                  Key_cache.Sync.write
                    (List.filter specs ~f:(function
                      | On_disk _ ->
                          true
                      | S3 _ ->
                          false ))
                    store () urs
                in
                urs
          in
          urs := Some u ;
          u
    in
    (set_urs_info, load)

  let create {Plonk_constraint_system.auxiliary_input_size; gates} =
    let t = Index.create gates (Unsigned.Size_t.of_int auxiliary_input_size) (load_urs ())
    in Caml.Gc.finalise Index.delete t ;
    t

  let vk t = Verifier_index.create t

  let pk = Fn.id

  open Pickles_types
end
