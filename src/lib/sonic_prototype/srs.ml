open Core
open Default_backend.Backend

module Srs = struct
  type t =
    { d: int
    ; gNegativeX: G1.t list
    ; gPositiveX: G1.t list
    ; hNegativeX: G2.t list
    ; hPositiveX: G2.t list
    ; gNegativeAlphaX: G1.t list
    ; gPositiveAlphaX: G1.t list
    ; hNegativeAlphaX: G2.t list
    ; hPositiveAlphaX: G2.t list
    ; srsPairing: Fq_target.t }

  let create d x alpha =
    let xInv = Fr.inv x in
    let g1 = G1.one in
    let g2 = G2.one in
    { d
    ; gNegativeX=
        List.map
          (List.range 1 (d + 1))
          ~f:(fun i ->
            G1.scale g1 (Fr.to_bigint (Fr.( ** ) xInv (N.of_int i))))
    ; gPositiveX=
        List.map
          (List.range 0 (d + 1))
          ~f:(fun i -> G1.scale g1 (Fr.to_bigint (Fr.( ** ) x (N.of_int i))))
    ; hNegativeX=
        List.map
          (List.range 1 (d + 1))
          ~f:(fun i ->
            G2.scale g2 (Fr.to_bigint (Fr.( ** ) xInv (N.of_int i))))
    ; hPositiveX=
        List.map
          (List.range 0 (d + 1))
          ~f:(fun i -> G2.scale g2 (Fr.to_bigint (Fr.( ** ) x (N.of_int i))))
    ; gNegativeAlphaX=
        List.map
          (List.range 1 (d + 1))
          ~f:(fun i ->
            G1.scale g1
              (Fr.to_bigint (Fr.( * ) alpha (Fr.( ** ) xInv (N.of_int i)))))
    ; gPositiveAlphaX=
        List.map
          (List.range 0 (d + 1))
          ~f:(fun i ->
            G1.scale g1
              (Fr.to_bigint (Fr.( * ) alpha (Fr.( ** ) x (N.of_int i)))))
    ; hNegativeAlphaX=
        List.map
          (List.range 1 (d + 1))
          ~f:(fun i ->
            G2.scale g2
              (Fr.to_bigint (Fr.( * ) alpha (Fr.( ** ) xInv (N.of_int i)))))
    ; hPositiveAlphaX=
        List.map
          (List.range 0 (d + 1))
          ~f:(fun i ->
            G2.scale g2
              (Fr.to_bigint (Fr.( * ) alpha (Fr.( ** ) x (N.of_int i)))))
    ; srsPairing= Pairing.reduced_pairing g1 (G2.scale g2 (Fr.to_bigint alpha))
    }
end
