open Core_kernel

(* TODO: temporary hack *)
[%%versioned
module Stable = struct
  module V2 = struct
    type t = Mina_wire_types.Mina_base.Control.V2.t =
      | Proof of Pickles.Side_loaded.Proof.Stable.V2.t
      | Signature of Signature.Stable.V1.t
      | None_given
    [@@deriving sexp, equal, yojson, hash, compare]

    let to_latest = Fn.id
  end
end]

(* lazy, to prevent spawning Rust threads at startup, which prevents daemonization *)
let gen_with_dummies : t Quickcheck.Generator.t =
  let gen =
    lazy
      (Quickcheck.Generator.of_list
         (let dummy_proof =
            let n2 = Pickles_types.Nat.N2.n in
            let proof = Pickles.Proof.dummy n2 n2 n2 ~domain_log2:15 in
            Proof proof
          in
          let dummy_signature = Signature Signature.dummy in
          [ dummy_proof; dummy_signature; None_given ] ) )
  in
  Quickcheck.Generator.create (fun ~size ~random ->
      Quickcheck.Generator.generate (Lazy.force gen) ~size ~random )

module Tag = struct
  type t = Signature | Proof | None_given [@@deriving equal, compare, sexp]

  let gen = Quickcheck.Generator.of_list [ Proof; Signature; None_given ]

  let to_string = function
    | Signature ->
        "Signature"
    | Proof ->
        "Proof"
    | None_given ->
        "None_given"

  let of_string_exn = function
    | "Signature" ->
        Signature
    | "Proof" ->
        Proof
    | "None_given" ->
        None_given
    | s ->
        failwithf "String %s does not denote a control tag" s ()
end

let tag : t -> Tag.t = function
  | Proof _ ->
      Proof
  | Signature _ ->
      Signature
  | None_given ->
      None_given

let dummy_of_tag : Tag.t -> t = function
  | Proof ->
      let n2 = Pickles_types.Nat.N2.n in
      let proof = Pickles.Proof.dummy n2 n2 n2 ~domain_log2:15 in
      Proof proof
  | Signature ->
      Signature Signature.dummy
  | None_given ->
      None_given

let signature_deriver obj =
  Fields_derivers_zkapps.Derivers.iso_string obj ~name:"Signature"
    ~js_type:String ~to_string:Signature.to_base58_check
    ~of_string:
      (Fields_derivers_zkapps.except ~f:Signature.of_base58_check_exn `Signature)

module As_record = struct
  type t =
    { proof : Pickles.Side_loaded.Proof.t option
    ; signature : Signature.t option
    }
  [@@deriving annot, fields]

  let deriver obj =
    let open Fields_derivers_zkapps in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj
      ~proof:!.(option ~js_type:Or_undefined @@ proof @@ o ())
      ~signature:!.(option ~js_type:Or_undefined @@ signature_deriver @@ o ())
    |> finish "Control" ~t_toplevel_annots
end

let to_record = function
  | Proof p ->
      { As_record.proof = Some p; signature = None }
  | Signature s ->
      { proof = None; signature = Some s }
  | None_given ->
      { proof = None; signature = None }

let of_record = function
  | { As_record.proof = Some p; _ } ->
      Proof p
  | { signature = Some s; _ } ->
      Signature s
  | _ ->
      None_given

let deriver obj =
  Fields_derivers_zkapps.Derivers.iso_record ~of_record ~to_record
    As_record.deriver obj

let%test_unit "json rountrip" =
  let module Fd = Fields_derivers_zkapps.Derivers in
  let full = deriver (Fd.o ()) in
  let control = dummy_of_tag Proof in
  [%test_eq: t] control (control |> Fd.to_json full |> Fd.of_json full)
