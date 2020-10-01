open Unsigned.Size_t

module type Stable_v1 = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving version, bin_io, sexp, compare, yojson, hash, eq]
    end

    module Latest = V1
  end

  type t = Stable.V1.t [@@deriving sexp, compare, yojson]
end

module type Inputs_intf = sig
  open Intf

  val name : string

  module Rounds : Pickles_types.Nat.Intf

  module Gate_vector : sig
    open Unsigned

    type t

    val wrap_gate : t -> size_t -> int -> size_t -> int -> unit
  end

  module Urs : sig
    type t

    val read : string -> t

    val write : t -> string -> unit

    val create : Unsigned.Size_t.t -> t
  end

  module Scalar_field : sig
    include Stable_v1

    include Type_with_delete with type t := t

    val one : t

    module Vector : sig
      include Vector with type elt = t
    end
  end

  module Constraint_system : sig
    type t = (Gate_vector.t, Scalar_field.t) Plonk_constraint_system.t

    val finalize_and_get_gates : t -> Gate_vector.t
  end

  module Index : sig
    type t

    val delete : t -> unit

    val create : Gate_vector.t -> Urs.t -> t
  end

  module Curve : sig
    module Affine : sig
      type t
    end
  end

  module Poly_comm : sig
    module Backend : T0

    type t = Curve.Affine.t Poly_comm.t

    val of_backend_without_degree_bound : Backend.t -> t
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

  type t =
    { index: Index.t
    ; cs: (Gate_vector.t, Scalar_field.t) Plonk_constraint_system.t }

  let name = sprintf "%s_%d_v2" name (Pickles_types.Nat.to_int Rounds.n)

  let set_urs_info, load_urs =
    let urs_info = Set_once.create () in
    let urs = ref None in
    let degree = 1 lsl Pickles_types.Nat.to_int Rounds.n in
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
                let urs = Urs.create (Unsigned.Size_t.of_int degree) in
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

  let create cs =
    let gates = Constraint_system.finalize_and_get_gates cs in
    let conv =
      Plonk_constraint_system.Row.to_absolute
        ~public_input_size:(Set_once.get_exn cs.public_input_size [%here])
    in
    Plonk_constraint_system.V.Table.iter cs.equivalence_classes ~f:(fun x ->
        if List.length x > 1 then
          let h = List.hd_exn x in
          let t = List.last_exn x in
          Gate_vector.wrap_gate gates (conv t.row) t.col (conv h.row) h.col ) ;
    let index = Index.create gates (load_urs ()) in
    Caml.Gc.finalise Index.delete index ;
    Core.printf "rows = %d\n%!" (List.length cs.rows_rev) ;
    {index; cs}

  let vk t = Verifier_index.create t.index

  let pk t = t

  open Pickles_types

  let vk_commitments t :
      Curve.Affine.t Dlog_plonk_types.Poly_comm.Without_degree_bound.t
      Plonk_verification_key_evals.t =
    let f (t : Poly_comm.Backend.t) =
      match Poly_comm.of_backend_without_degree_bound t with
      | `Without_degree_bound a ->
          a
      | _ ->
          assert false
    in
    let open Verifier_index in
    { sigma_comm_0= f (sigma_comm_0 t)
    ; sigma_comm_1= f (sigma_comm_1 t)
    ; sigma_comm_2= f (sigma_comm_2 t)
    ; ql_comm= f (ql_comm t)
    ; qr_comm= f (qr_comm t)
    ; qo_comm= f (qo_comm t)
    ; qm_comm= f (qm_comm t)
    ; qc_comm= f (qc_comm t)
    ; rcm_comm_0= f (rcm_comm_0 t)
    ; rcm_comm_1= f (rcm_comm_1 t)
    ; rcm_comm_2= f (rcm_comm_2 t)
    ; psm_comm= f (psm_comm t)
    ; add_comm= f (add_comm t)
    ; mul1_comm= f (mul1_comm t)
    ; mul2_comm= f (mul2_comm t)
    ; emul1_comm= f (emul1_comm t)
    ; emul2_comm= f (emul2_comm t)
    ; emul3_comm= f (emul3_comm t) }
end
