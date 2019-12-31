module Evals = struct
  type 'a t =
    { sg_old: 'a
    ; x_hat: 'a
    ; w_hat: 'a
    ; s: 'a
    ; z_hat_a: 'a
    ; z_hat_b: 'a
    ; h_1: 'a
    ; h_2: 'a
    ; h_3: 'a
    ; row_a: 'a
    ; row_b: 'a
    ; row_c: 'a
    ; col_a: 'a
    ; col_b: 'a
    ; col_c: 'a
    ; value_a: 'a
    ; value_b: 'a
    ; value_c: 'a
    ; g_1: 'a
    ; g_2: 'a
    ; g_3: 'a }
  [@@deriving fields]

  let to_vectors
      { sg_old
      ; x_hat
      ; w_hat
      ; s
      ; z_hat_a
      ; z_hat_b
      ; h_1
      ; h_2
      ; h_3
      ; row_a
      ; row_b
      ; row_c
      ; col_a
      ; col_b
      ; col_c
      ; value_a
      ; value_b
      ; value_c
      ; g_1
      ; g_2
      ; g_3 } =
    Vector.
      ( [ sg_old
        ; x_hat
        ; w_hat
        ; s
        ; z_hat_a
        ; z_hat_b
        ; h_1
        ; h_2
        ; h_3
        ; row_a
        ; row_b
        ; row_c
        ; col_a
        ; col_b
        ; col_c
        ; value_a
        ; value_b
        ; value_c ]
      , [g_1; g_2; g_3] )

  let of_vectors
      (( [ sg_old
         ; x_hat
         ; w_hat
         ; s
         ; z_hat_a
         ; z_hat_b
         ; h_1
         ; h_2
         ; h_3
         ; row_a
         ; row_b
         ; row_c
         ; col_a
         ; col_b
         ; col_c
         ; value_a
         ; value_b
         ; value_c ]
       , [g_1; g_2; g_3] ) :
        ('a, _) Vector.t * ('a, _) Vector.t) : 'a t =
    { sg_old
    ; x_hat
    ; w_hat
    ; s
    ; z_hat_a
    ; z_hat_b
    ; h_1
    ; h_2
    ; h_3
    ; row_a
    ; row_b
    ; row_c
    ; col_a
    ; col_b
    ; col_c
    ; value_a
    ; value_b
    ; value_c
    ; g_1
    ; g_2
    ; g_3 }

  let typ fq =
    let t =
      Snarky.Typ.tuple2 (Vector.typ fq Nat.N18.n) (Vector.typ fq Nat.N3.n)
    in
    Snarky.Typ.transport t ~there:to_vectors ~back:of_vectors
    |> Snarky.Typ.transport_var ~there:to_vectors ~back:of_vectors
end
