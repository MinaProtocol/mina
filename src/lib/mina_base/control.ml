[%%import "/src/config.mlh"]

open Core_kernel

(* TODO: temporary hack *)
[%%ifdef consensus_mechanism]

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      | Proof of Pickles.Side_loaded.Proof.Stable.V1.t
      | Signature of Signature.Stable.V1.t
      | None_given
    [@@deriving sexp, equal, yojson, hash, compare]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t =
      | Proof of Pickles.Side_loaded.Proof.Stable.V1.t
      | Signature of Signature.Stable.V1.t
      | Both of
          { signature : Signature.Stable.V1.t
          ; proof : Pickles.Side_loaded.Proof.Stable.V1.t
          }
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

(* lazy, to prevent spawning Rust threads at startup, which prevents daemonization *)
let gen_with_dummies : t Quickcheck.Generator.t Lazy.t =
  lazy
    (Quickcheck.Generator.of_list
       (let dummy_proof =
          let n2 = Pickles_types.Nat.N2.n in
          let proof = Pickles.Proof.dummy n2 n2 n2 in
          Proof proof
        in
        let dummy_signature = Signature Signature.dummy in
        [ dummy_proof; dummy_signature; None_given ]))

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
  type t = Proof | Signature | None_given [@@deriving equal, compare, sexp]

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
      let proof = Pickles.Proof.dummy n2 n2 n2 in
      Proof proof
  | Signature ->
      Signature Signature.dummy
  | None_given ->
      None_given

[%%endif]
