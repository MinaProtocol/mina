(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Pickles_composition_types.Branch_data

module Make_sig (A : Wire_types.Types.S) = struct
  module type S =
    Branch_data_intf.S
      with type Domain_log2.Stable.V1.t = A.Domain_log2.V1.t
       and type Stable.V1.t = A.V1.t
end

module Make_str (A : Wire_types.Concrete) = struct
  (** Data specific to a branch of a proof-system that's necessary for
    finalizing the deferred-values in a wrap proof of that branch. *)

  module Proofs_verified = Pickles_base.Proofs_verified

  module Domain_log2 = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = char [@@deriving compare, sexp, yojson, hash, equal]

        let to_latest = Fn.id
      end
    end]

    let of_int_exn : int -> t = Char.of_int_exn

    let of_bits_msb (bs : bool list) : t =
      List.fold bs ~init:0 ~f:(fun acc b ->
          let acc = acc lsl 1 in
          if b then acc + 1 else acc )
      |> of_int_exn

    let of_field_exn (type f)
        (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
        (x : f) : t =
      Impl.Field.Constant.unpack x
      |> Fn.flip List.take 8 |> List.rev |> of_bits_msb
  end

  (* We pack this into a single field element as follows:
     First 2 bits: proofs_verified
     Next 8 bits: domain_log2 *)
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = A.V1.t =
        { proofs_verified : Proofs_verified.Stable.V1.t
        ; domain_log2 : Domain_log2.Stable.V1.t
        }
      [@@deriving hlist, compare, sexp, yojson, hash, equal]

      let to_latest = Fn.id
    end
  end]

  let length_in_bits = 10

  let pack (type f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
      ({ proofs_verified; domain_log2 } : t) : f =
    let open Impl.Field.Constant in
    let double x = x + x in
    let times4 x = double (double x) in
    let domain_log2 = of_int (Char.to_int domain_log2) in
    (* shift domain_log2 over by 2 bits (multiply by 4) *)
    times4 domain_log2
    + project
        (Pickles_types.Vector.to_list
           (Proofs_verified.to_bool_vec proofs_verified) )

  let unpack (type f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
      (x : f) : t =
    match Impl.Field.Constant.unpack x with
    | x0 :: x1 :: y0 :: y1 :: y2 :: y3 :: y4 :: y5 :: y6 :: y7 :: _ ->
        { proofs_verified = Proofs_verified.of_bool_vec [ x0; x1 ]
        ; domain_log2 =
            Domain_log2.of_bits_msb [ y7; y6; y5; y4; y3; y2; y1; y0 ]
        }
    | _ ->
        assert false

  open Kimchi_pasta_snarky_backend

  module Checked = struct
    module Step = struct
      open Step_impl

      type field_var = Field.t

      type t =
        { proofs_verified_mask : Proofs_verified.Prefix_mask.Step.Checked.t
        ; domain_log2 : Field.t
        }
      [@@deriving hlist]

      let pack ({ proofs_verified_mask; domain_log2 } : t) : Field.t =
        let open Field in
        let four = of_int 4 in
        (four * domain_log2)
        + pack (Pickles_types.Vector.to_list proofs_verified_mask)
    end

    module Wrap = struct
      open Wrap_impl

      type field_var = Field.t

      type t =
        { proofs_verified_mask : Proofs_verified.Prefix_mask.Wrap.Checked.t
        ; domain_log2 : Field.t
        }
      [@@deriving hlist]

      let pack ({ proofs_verified_mask; domain_log2 } : t) : Field.t =
        let open Field in
        let four = of_int 4 in
        (four * domain_log2)
        + pack (Pickles_types.Vector.to_list proofs_verified_mask)
    end
  end

  let packed_typ =
    Step_impl.Typ.transport Step_impl.Typ.field
      ~there:(pack (module Step_impl))
      ~back:(unpack (module Step_impl))

  let wrap_packed_typ =
    Wrap_impl.Typ.transport Wrap_impl.Typ.field
      ~there:(pack (module Wrap_impl))
      ~back:(unpack (module Wrap_impl))

  let typ
      ~(* We actually only need it to be less than 252 bits in order to pack
          the whole branch_data struct safely, but it's cheapest to check that it's
          under 16 bits *)
      (assert_16_bits : Step_impl.Field.t -> unit) :
      (Checked.Step.t, t) Step_impl.Typ.t =
    let open Step_impl in
    let proofs_verified_mask :
        (Proofs_verified.Prefix_mask.Step.Checked.t, Proofs_verified.t) Typ.t =
      Proofs_verified.Prefix_mask.Step.typ
    in
    let domain_log2 : (Field.t, Domain_log2.t) Typ.t =
      let (Typ t) =
        Typ.transport Field.typ
          ~there:(fun (x : char) -> Field.Constant.of_int (Char.to_int x))
          ~back:(Domain_log2.of_field_exn (module Step_impl))
      in
      let check (x : Field.t) = make_checked (fun () -> assert_16_bits x) in
      Typ { t with check }
    in
    Typ.of_hlistable
      [ proofs_verified_mask; domain_log2 ]
      ~value_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~var_to_hlist:Checked.Step.to_hlist ~var_of_hlist:Checked.Step.of_hlist

  let wrap_typ
      ~(* We actually only need it to be less than 252 bits in order to pack
          the whole branch_data struct safely, but it's cheapest to check that it's
          under 16 bits *)
      (assert_16_bits : Wrap_impl.Field.t -> unit) :
      (Checked.Wrap.t, t) Wrap_impl.Typ.t =
    let open Wrap_impl in
    let proofs_verified_mask :
        (Proofs_verified.Prefix_mask.Wrap.Checked.t, Proofs_verified.t) Typ.t =
      Proofs_verified.Prefix_mask.Wrap.typ
    in
    let domain_log2 : (Field.t, Domain_log2.t) Typ.t =
      let (Typ t) =
        Typ.transport Field.typ
          ~there:(fun (x : char) -> Field.Constant.of_int (Char.to_int x))
          ~back:(Domain_log2.of_field_exn (module Wrap_impl))
      in
      let check (x : Field.t) = make_checked (fun () -> assert_16_bits x) in
      Typ { t with check }
    in
    Typ.of_hlistable
      [ proofs_verified_mask; domain_log2 ]
      ~value_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~var_to_hlist:Checked.Wrap.to_hlist ~var_of_hlist:Checked.Wrap.of_hlist

  let domain { domain_log2; _ } =
    Pickles_base.Domain.Pow_2_roots_of_unity (Char.to_int domain_log2)
end

include Wire_types.Make (Make_sig) (Make_str)
