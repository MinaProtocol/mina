open Tuple_lib
open Core_kernel

module Evals = struct
  type 'a t =
    { w_hat: 'a array
    ; z_hat_a: 'a array
    ; z_hat_b: 'a array
    ; h_1: 'a array
    ; h_2: 'a array
    ; h_3: 'a array
    ; row: 'a array Abc.t
    ; col: 'a array Abc.t
    ; value: 'a array Abc.t
    ; rc: 'a array Abc.t
    ; g_1: 'a array
    ; g_2: 'a array
    ; g_3: 'a array }
  [@@deriving fields, bin_io]

  let to_vectors
      { w_hat
      ; z_hat_a
      ; z_hat_b
      ; h_1
      ; h_2
      ; h_3
      ; row= {a= row_a; b= row_b; c= row_c}
      ; col= {a= col_a; b= col_b; c= col_c}
      ; value= {a= value_a; b= value_b; c= value_c}
      ; rc= {a= rc_a; b= rc_b; c= rc_c}
      ; g_1
      ; g_2
      ; g_3 } =
    Vector.
      ( [ w_hat
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
        ; rc_c ]
      , [g_1; g_2; g_3] )

  let of_vectors
      (( [ w_hat
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
         ; rc_c ]
       , [g_1; g_2; g_3] ) :
        ('a array, _) Vector.t * ('a array, _) Vector.t) : 'a t =
    { w_hat
    ; z_hat_a
    ; z_hat_b
    ; h_1
    ; h_2
    ; h_3
    ; row= {a= row_a; b= row_b; c= row_c}
    ; col= {a= col_a; b= col_b; c= col_c}
    ; value= {a= value_a; b= value_b; c= value_c}
    ; rc= {a= rc_a; b= rc_b; c= rc_c}
    ; g_1
    ; g_2
    ; g_3 }

  let typ fg =
    let t =
      Snarky.Typ.tuple2 (Vector.typ fg Nat.N18.n) (Vector.typ fg Nat.N3.n)
    in
    Snarky.Typ.transport t ~there:to_vectors ~back:of_vectors
    |> Snarky.Typ.transport_var ~there:to_vectors ~back:of_vectors
end

module Openings = struct
  module Bulletproof = struct
    type ('fg, 'g) t =
      {lr: ('g * 'g) array; z_1: 'fg; z_2: 'fg; delta: 'g; sg: 'g}
    [@@deriving bin_io]

    open Snarky.H_list

    let to_hlist {lr; z_1; z_2; delta; sg} = [lr; z_1; z_2; delta; sg]

    let of_hlist ([lr; z_1; z_2; delta; sg] : (unit, _) t) =
      {lr; z_1; z_2; delta; sg}

    let typ fg g ~length =
      let open Snarky.Typ in
      of_hlistable
        [array ~length (g * g); fg; fg; g; g]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  open Evals

  type ('fg, 'g) t =
    {proof: ('fg, 'g) Bulletproof.t; evals: 'fg Evals.t Triple.t}
  [@@deriving bin_io]

  let to_hlist {proof; evals} = Snarky.H_list.[proof; evals]

  let of_hlist ([proof; evals] : (unit, _) Snarky.H_list.t) = {proof; evals}

  let typ fg fgv g ~length =
    let open Snarky.Typ in
    let triple x = tuple3 x x x in
    of_hlistable
      [Bulletproof.typ fg g ~length; triple (Evals.typ fgv)]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module PolyComm = struct
  type 'g t =
    {unshifted: 'g array; shifted: 'g option}
  [@@deriving bin_io]

  let to_hlist {unshifted; shifted} = Snarky.H_list.[unshifted; shifted]

  let of_hlist ([unshifted; shifted] : (unit, _) Snarky.H_list.t) = {unshifted; shifted}

  let typ g opt ~length =
    let open Snarky.Typ in
    of_hlistable
      [array ~length g; opt]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Challenge_polynomial = struct
  type ('fg, 'g) t = {challenges: 'fg array; commitment: ('g) PolyComm.t} [@@deriving bin_io]

  open Snarky.H_list

  let to_hlist {challenges; commitment} = [challenges; commitment]

  let of_hlist ([challenges; commitment] : (unit, _) t) = {challenges; commitment}

  let typ fg pc ~length =
    let open Snarky.Typ in
    of_hlistable
      [array ~length fg; pc]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Messages = struct
  type ('fg, 'g) t =
    { w_hat: (('g) PolyComm.t)
    ; z_hat_a: (('g) PolyComm.t)
    ; z_hat_b: (('g) PolyComm.t)
    ; gh_1: (('g) PolyComm.t) * (('g) PolyComm.t)
    ; sigma_gh_2: 'fg * ((('g) PolyComm.t) * (('g) PolyComm.t))
    ; sigma_gh_3: 'fg * ((('g) PolyComm.t) * (('g) PolyComm.t)) }
  [@@deriving fields, bin_io]

  let to_hlist {w_hat; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3} =
    Snarky.H_list.[w_hat; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3]

  let of_hlist
      ([w_hat; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3] :
        (unit, _) Snarky.H_list.t) =
    {w_hat; z_hat_a; z_hat_b; gh_1; sigma_gh_2; sigma_gh_3}

  let typ fg g opt ~length =
    let open Snarky.Typ in
    let pc = PolyComm.typ g opt ~length in
    of_hlistable
      [pc; pc; pc; pc * pc; fg * (pc * pc); fg * (pc * pc)]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end
(*
module Proof = struct
  type ('fg, 'g) t =
    {
      messages: ('fg, 'g) Messages.t; 
      opening: ('fg, 'g) Openings.t; 
      challenges: (('fg, ('g) PolyComm.t) Challenge_polynomial.t) array;
    }
  [@@(* ('proof, 'fg) Openings.t} *)
    deriving fields, bin_io]

  let to_hlist {messages; opening; challenges} = Snarky.H_list.[messages; opening; challenges]

  let of_hlist ([messages; opening; challenges] : (unit, _) Snarky.H_list.t) =
    {messages; opening; challenges}

  let typ pc fg fgv opening challenges ~length =
    let open Snarky.Typ in
    Snarky.Typ.of_hlistable
      [Messages.typ pc fg; opening; array ~length challenges]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end
*)
module Proof = struct
  type ('fg, 'g) t =
    {
      messages: ('fg, 'g) Messages.t; 
      opening: ('fg, 'g) Openings.t; 
    }
  [@@(* ('proof, 'fg) Openings.t} *)
    deriving fields, bin_io]

  let to_hlist {messages; opening;} = Snarky.H_list.[messages; opening;]

  let of_hlist ([messages; opening;] : (unit, _) Snarky.H_list.t) =
    {messages; opening;}

  let typ fg fgv g opt ~length =
    let open Snarky.Typ in
    Snarky.Typ.of_hlistable
      [Messages.typ fg g opt ~length; Openings.typ fg fgv g ~length]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end
