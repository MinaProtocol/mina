open Core

module Make (Backend : Backend.Backend_intf) = struct
  open Backend

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
            G1.scale_plus_minus g1 (Fr.to_bigint (Fr.( ** ) xInv (N.of_int i))))
    ; gPositiveX=
        List.map
          (List.range 0 (d + 1))
          ~f:(fun i ->
            G1.scale_plus_minus g1 (Fr.to_bigint (Fr.( ** ) x (N.of_int i))))
    ; hNegativeX=
        List.map
          (List.range 1 (d + 1))
          ~f:(fun i ->
            G2.scale_plus_minus g2 (Fr.to_bigint (Fr.( ** ) xInv (N.of_int i))))
    ; hPositiveX=
        List.map
          (List.range 0 (d + 1))
          ~f:(fun i ->
            G2.scale_plus_minus g2 (Fr.to_bigint (Fr.( ** ) x (N.of_int i))))
    ; gNegativeAlphaX=
        List.map
          (List.range 1 (d + 1))
          ~f:(fun i ->
            G1.scale_plus_minus g1
              (Fr.to_bigint (Fr.( * ) alpha (Fr.( ** ) xInv (N.of_int i)))))
    ; gPositiveAlphaX=
        G1.zero
        :: List.map
             (List.range 1 (d + 1))
             ~f:(fun i ->
               G1.scale_plus_minus g1
                 (Fr.to_bigint (Fr.( * ) alpha (Fr.( ** ) x (N.of_int i)))))
    ; hNegativeAlphaX=
        List.map
          (List.range 1 (d + 1))
          ~f:(fun i ->
            G2.scale_plus_minus g2
              (Fr.to_bigint (Fr.( * ) alpha (Fr.( ** ) xInv (N.of_int i)))))
    ; hPositiveAlphaX=
        List.map
          (List.range 0 (d + 1))
          ~f:(fun i ->
            G2.scale_plus_minus g2
              (Fr.to_bigint (Fr.( * ) alpha (Fr.( ** ) x (N.of_int i)))))
    ; srsPairing=
        Pairing.reduced_pairing g1
          (G2.scale_plus_minus g2 (Fr.to_bigint alpha)) }

  let select_helper positives negatives poly init plus scale =
    let rec accum current_deg remaining_coeffs so_far =
      match remaining_coeffs with
      | [] ->
          so_far
      | hd :: tl ->
          let next =
            if current_deg < 0 then List.nth_exn negatives (-1 - current_deg)
            else List.nth_exn positives current_deg
          in
          accum (current_deg + 1) tl
            (plus (scale next (Fr.to_bigint hd)) so_far)
    in
    let deg = Fr_laurent.deg poly in
    let coeffs = Fr_laurent.coeffs poly in
    accum deg coeffs init

  let select_g (srs : t) poly =
    select_helper srs.gPositiveX srs.gNegativeX poly G1.zero G1.( + )
      G1.scale_plus_minus

  let select_g_alpha (srs : t) poly =
    select_helper srs.gPositiveAlphaX srs.gNegativeAlphaX poly G1.zero G1.( + )
      G1.scale_plus_minus

  let select_h (srs : t) poly =
    select_helper srs.hPositiveX srs.hNegativeX poly G2.zero G2.( + )
      G2.scale_plus_minus

  let select_h_alpha (srs : t) poly =
    select_helper srs.hPositiveAlphaX srs.hNegativeAlphaX poly G2.zero G2.( + )
      G2.scale_plus_minus
end
