[%%import "/src/config.mlh"]

open Core_kernel

(* TODO: temporary hack *)
[%%ifdef consensus_mechanism]

(* we could use With_hash, but the hash is not of the data, the proof *)
module Proof_with_vk_hash = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('proof, 'hash) t =
            ( 'proof
            , 'hash )
            Mina_wire_types.Mina_base.Control.Proof_with_vk_hash.V1.t =
        { proof : 'proof; verification_key_hash : 'hash }
      [@@deriving sexp, yojson, hash, equal, compare]
    end
  end]
end

(* TODO: yojson for Field.t in snarky *)
[%%versioned
module Stable = struct
  module V2 = struct
    type t = Mina_wire_types.Mina_base.Control.V2.t =
      | Proof of
          ( Pickles.Side_loaded.Proof.Stable.V2.t
          , (Snark_params.Tick.Field.t
            [@version_asserted]
            [@to_yojson fun t -> `String (Snark_params.Tick.Field.to_string t)]
            [@of_yojson
              function
              | `String s ->
                  let field = Snark_params.Tick.Field.of_string s in
                  let s' = Snark_params.Tick.Field.to_string field in
                  if String.equal s s' then Ok field
                  else Error "Invalid JSON for field"
              | _ ->
                  Error "expected JSON string"] ) )
          Proof_with_vk_hash.Stable.V1.t
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
            Proof
              { proof; verification_key_hash = Zkapp_account.dummy_vk_hash () }
          in
          let dummy_signature = Signature Signature.dummy in
          [ dummy_proof; dummy_signature; None_given ] ) )
  in
  Quickcheck.Generator.create (fun ~size ~random ->
      Quickcheck.Generator.generate (Lazy.force gen) ~size ~random )

[%%else]

[%%versioned
module Stable = struct
  module V2 = struct
    type t = Proof of unit | Signature of Signature.Stable.V1.t | None_given
    [@@deriving sexp, equal, yojson, hash, compare]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t =
      | Proof of unit
      | Signature of Signature.Stable.V1.t
      | Both of { signature : Signature.Stable.V1.t; proof : unit }
      | None_given
    [@@deriving sexp, equal, yojson, hash, compare]

    let to_latest : t -> V2.t = function
      | Proof proof ->
          Proof proof
      | Signature signature ->
          Signature signature
      | None_given ->
          None_given
      | Both _ ->
          failwith
            "Control.Stable.V1.to_latest: Both variant is no longer supported"
  end
end]

[%%endif]

module Tag = struct
  type t = Mina_wire_types.Mina_base.Account_update.Authorization_kind.V1.t =
    | Signature
    | Proof
    | None_given
  [@@deriving equal, compare, sexp]

  let gen = Quickcheck.Generator.of_list [ Proof; Signature; None_given ]
end

let tag : t -> Tag.t = function
  | Proof _ ->
      Proof
  | Signature _ ->
      Signature
  | None_given ->
      None_given

[%%ifdef consensus_mechanism]

let dummy_of_tag : Tag.t -> t = function
  | Proof ->
      let n2 = Pickles_types.Nat.N2.n in
      let proof = Pickles.Proof.dummy n2 n2 n2 ~domain_log2:15 in
      Proof { proof; verification_key_hash = Zkapp_account.dummy_vk_hash () }
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
  (* rather than group the proof and vk hash in a record, as in the type `t`, we
     make them separate elements to simplify the deriver
  *)
  type t =
    { proof : Pickles.Side_loaded.Proof.t option
    ; verification_key_hash : Snark_params.Tick.Field.t option
    ; signature : Signature.t option
    }
  [@@deriving annot, fields]

  let deriver obj =
    let open Fields_derivers_zkapps in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj
      ~proof:!.(option ~js_type:Or_undefined @@ proof @@ o ())
      ~verification_key_hash:!.(option ~js_type:Or_undefined @@ field @@ o ())
      ~signature:!.(option ~js_type:Or_undefined @@ signature_deriver @@ o ())
    |> finish "Control" ~t_toplevel_annots
end

let to_record = function
  | Proof { proof; verification_key_hash } ->
      { As_record.proof = Some proof
      ; verification_key_hash = Some verification_key_hash
      ; signature = None
      }
  | Signature s ->
      { proof = None; verification_key_hash = None; signature = Some s }
  | None_given ->
      { proof = None; verification_key_hash = None; signature = None }

let of_record = function
  | { As_record.proof = Some p; verification_key_hash = Some vk_hash; _ } ->
      Proof { proof = p; verification_key_hash = vk_hash }
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

[%%endif]
