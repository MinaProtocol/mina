open Core_kernel
open Pickles_types

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
           (Proofs_verified.Prefix_mask.there proofs_verified) )

  let unpack (type f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
      (x : f) : t =
    match Impl.Field.Constant.unpack x with
    | x0 :: x1 :: y0 :: y1 :: y2 :: y3 :: y4 :: y5 :: y6 :: y7 :: _ ->
        { proofs_verified = Proofs_verified.Prefix_mask.back [ x0; x1 ]
        ; domain_log2 =
            Domain_log2.of_bits_msb [ y7; y6; y5; y4; y3; y2; y1; y0 ]
        }
    | _ ->
        assert false

  module Checked = struct
    type 'f t =
      { proofs_verified_mask : 'f Proofs_verified.Prefix_mask.Checked.t
      ; domain_log2 : 'f Snarky_backendless.Cvar.t
      }
    [@@deriving hlist]

    let pack (type f)
        (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
        ({ proofs_verified_mask; domain_log2 } : f t) : Impl.Field.t =
      let open Impl.Field in
      let four = of_int 4 in
      (four * domain_log2)
      + pack (Pickles_types.Vector.to_list proofs_verified_mask)
  end

  let packed_typ (type f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) =
    Impl.Typ.transport Impl.Typ.field
      ~there:(pack (module Impl))
      ~back:(unpack (module Impl))

  let typ (type f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
      ~(* We actually only need it to be less than 252 bits in order to pack
          the whole branch_data struct safely, but it's cheapest to check that it's
          under 16 bits *)
      (assert_16_bits : Impl.Field.t -> unit) : (f Checked.t, t) Impl.Typ.t =
    let open Impl in
    let proofs_verified_mask :
        (f Proofs_verified.Prefix_mask.Checked.t, Proofs_verified.t) Typ.t =
      Proofs_verified.Prefix_mask.typ (module Impl)
    in
    let domain_log2 : (Field.t, Domain_log2.t) Typ.t =
      let (Typ t) =
        Typ.transport Field.typ
          ~there:(fun (x : char) -> Field.Constant.of_int (Char.to_int x))
          ~back:(Domain_log2.of_field_exn (module Impl))
      in
      let check (x : Field.t) = make_checked (fun () -> assert_16_bits x) in
      Typ { t with check }
    in
    Typ.of_hlistable
      [ proofs_verified_mask; domain_log2 ]
      ~value_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist

  let domain { domain_log2; _ } =
    Pickles_base.Domain.Pow_2_roots_of_unity (Char.to_int domain_log2)
end

include Wire_types.Make (Make_sig) (Make_str)
