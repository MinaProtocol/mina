open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('proof, 'signature) t =
            ('proof, 'signature) Mina_wire_types.Mina_base.Control.Poly.V1.t =
        | Proof of 'proof
        | Signature of 'signature
        | None_given
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]
end

(* TODO: temporary hack *)
[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      ( Pickles.Side_loaded.Proof.Stable.V2.t
      , Signature.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving sexp, equal, yojson, hash, compare]

    let to_latest = Fn.id
  end
end]

module Serializable_type = struct
  type raw_serializable = Stable.Latest.t

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( Proof_cache_tag.Serializable_type.Stable.V2.t
        , Signature.Stable.V1.t )
        Poly.Stable.V1.t

      let to_latest = Fn.id
    end
  end]

  let to_raw_serializable : t -> raw_serializable = function
    | Proof proof ->
        Proof (Proof_cache_tag.Serializable_type.to_proof proof)
    | Signature s ->
        Signature s
    | None_given ->
        None_given
end

type t = (Proof_cache_tag.t, Signature.t) Poly.t [@@deriving sexp_of, to_yojson]

let to_serializable_type : t -> Serializable_type.t = function
  | Proof proof ->
      Proof (Proof_cache_tag.Serializable_type.of_cache_tag proof)
  | Signature s ->
      Signature s
  | None_given ->
      None_given

(* lazy, to prevent spawning Rust threads at startup, which prevents daemonization *)
let gen_with_dummies : Stable.Latest.t Quickcheck.Generator.t =
  let gen =
    lazy
      (Quickcheck.Generator.of_list
         (let dummy_proof =
            let n2 = Pickles_types.Nat.N2.n in
            let proof = Pickles.Proof.dummy n2 n2 ~domain_log2:15 in
            Poly.Proof proof
          in
          let dummy_signature = Poly.Signature Signature.dummy in
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

let tag : ('proof, 'signature) Poly.t -> Tag.t = function
  | Proof _ ->
      Proof
  | Signature _ ->
      Signature
  | None_given ->
      None_given

let dummy_of_tag : Tag.t -> Stable.Latest.t = function
  | Proof ->
      let n2 = Pickles_types.Nat.N2.n in
      let proof = Pickles.Proof.dummy n2 n2 ~domain_log2:15 in
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
  | Poly.Proof p ->
      { As_record.proof = Some p; signature = None }
  | Signature s ->
      { proof = None; signature = Some s }
  | None_given ->
      { proof = None; signature = None }

let of_record = function
  | { As_record.proof = Some p; _ } ->
      Poly.Proof p
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
  [%test_eq: Stable.Latest.t] control
    (control |> Fd.to_json full |> Fd.of_json full)
