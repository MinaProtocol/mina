open Tuple_lib
open Core_kernel

module Evals = struct
  type 'a t =
    { 
      w_hat: 'a
    ; z_hat_a: 'a
    ; z_hat_b: 'a
    ; h_1: 'a
    ; h_2: 'a
    ; h_3: 'a
    ; row: 'a Abc.t
    ; col: 'a Abc.t
    ; value: 'a Abc.t
    ; rc: 'a Abc.t

    ; g_1: 'a
    ; g_2: 'a
    ; g_3: 'a }
  [@@deriving fields, bin_io]

  let to_vectors
      {
        w_hat
      ; z_hat_a
      ; z_hat_b
      ; h_1
      ; h_2
      ; h_3
      ; row={a= row_a
      ; b=row_b
            ; c=row_c }
      ; col={a=col_a
      ; b=col_b
            ; c=col_c}
      ; value={a=value_a
      ; b=value_b
              ; c=value_c }
      ; rc={a=rc_a
      ; b=rc_b
           ; c=rc_c}
      ; g_1
      ; g_2
      ; g_3 } =
    Vector.
      ( [ 
          w_hat
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
        ; rc_a
        ; rc_b
        ; rc_c
        ]
      , [g_1; g_2; g_3] )

  let of_vectors
      (( [ 
           w_hat
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
        ; rc_a
        ; rc_b
        ; rc_c
         ]
       , [g_1; g_2; g_3] ) :
        ('a, _) Vector.t * ('a, _) Vector.t) : 'a t =
    { 
      w_hat
    ; z_hat_a
    ; z_hat_b
    ; h_1
    ; h_2
    ; h_3
    ; row={a=row_a
    ; b=row_b
          ; c=row_c }
    ; col={a=col_a
    ; b=col_b
          ; c=col_c }
    ; value={a=value_a
    ; b=value_b
            ; c=value_c }
        ; rc={a=rc_a
        ; b=rc_b
             ; c=rc_c }
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

module Openings = struct
  module Bulletproof = struct
    type ('fq, 'g) t =
      {lr: ('g * 'g) array; z_1: 'fq; z_2: 'fq; delta: 'g
        ; sg : 'g
      }
    [@@deriving bin_io]

    open Snarky.H_list

    let to_hlist {lr; z_1; z_2; delta; sg} =
      [lr; z_1; z_2; delta; sg]

    let of_hlist ([lr; z_1; z_2; delta; sg] : (unit, _) t) =
      {lr; z_1; z_2; delta; sg}

    let typ fq g ~length =
      let open Snarky.Typ in
      of_hlistable
        [array ~length (g * g); fq; fq; g; g]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
  end

  open Evals

  type ('fq, 'g) t = {proof: ('fq, 'g) Bulletproof.t ; evals: 'fq Evals.t Triple.t}
  [@@deriving bin_io]

  let to_hlist {proof; evals} = Snarky.H_list.[proof; evals]

  let of_hlist ([proof; evals] : (unit, _) Snarky.H_list.t) = {proof; evals}

  let typ fq g ~length =
    let open Snarky.Typ in
    let triple x = tuple3 x x x in
    of_hlistable
      [Bulletproof.typ fq g ~length; triple (Evals.typ fq)]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end
