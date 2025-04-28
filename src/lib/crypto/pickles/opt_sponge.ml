open Core_kernel

(* This module implements snarky functions for a sponge that can *conditionally* absorb input,
   while branching minimally. Specifically, if absorbing N field elements, this sponge can absorb
   a variable subset of N field elements, while performing N + 1 invocations of the sponge's
   underlying permutation. *)

let m = 3

let capacity = 1

let rate = m - capacity

type 'f sponge_state =
  | Absorbing of
      { next_index : 'f Snarky_backendless.Boolean.t
      ; xs : ('f Snarky_backendless.Boolean.t * 'f) list
      }
  | Squeezed of int

type 'f t =
  { mutable state : 'f array
  ; params : 'f Sponge.Params.t
  ; mutable needs_final_permute_if_empty : bool
  ; mutable sponge_state : 'f sponge_state
  }

module Make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (P : Sponge.Intf.Permutation with type Field.t = Impl.Field.t) =
struct
  open P
  open Impl

  type nonrec t = Field.t t

  let _state { state; _ } = Array.copy state

  let copy { state; params; sponge_state; needs_final_permute_if_empty } =
    { state = Array.copy state
    ; params
    ; sponge_state
    ; needs_final_permute_if_empty
    }

  let initial_state = Array.init m ~f:(fun _ -> Field.zero)

  let of_sponge { Sponge.state; params; sponge_state; id = _ } =
    match sponge_state with
    | Sponge.Squeezed n ->
        { sponge_state = Squeezed n
        ; state = Array.copy state
        ; needs_final_permute_if_empty = true
        ; params
        }
    | Sponge.Absorbed n -> (
        let abs i =
          { sponge_state = Absorbing { next_index = i; xs = [] }
          ; state = Array.copy state
          ; params
          ; needs_final_permute_if_empty = true
          }
        in
        match n with
        | 0 ->
            abs Boolean.false_
        | 1 ->
            abs Boolean.true_
        | 2 ->
            { sponge_state = Absorbing { next_index = Boolean.false_; xs = [] }
            ; state = P.block_cipher params state
            ; needs_final_permute_if_empty = false
            ; params
            }
        | _ ->
            assert false )

  let create ?(init = initial_state) params =
    { params
    ; state = Array.copy init
    ; needs_final_permute_if_empty = true
    ; sponge_state = Absorbing { next_index = Boolean.false_; xs = [] }
    }

  let () = assert (rate = 2)

  let add_in a i x =
    let i_equals_0 = Boolean.not i in
    let i_equals_1 = i in
    (*
      a.(0) <- a.(0) + i_equals_0 * x
      a.(1) <- a.(1) + i_equals_1 * x *)
    List.iteri [ i_equals_0; i_equals_1 ] ~f:(fun j i_equals_j ->
        let a_j' =
          exists Field.typ
            ~compute:
              As_prover.(
                fun () ->
                  let a_j = read Field.typ a.(j) in
                  if read Boolean.typ i_equals_j then
                    Field.Constant.(a_j + read Field.typ x)
                  else a_j)
        in
        assert_r1cs x (i_equals_j :> Field.t) Field.(a_j' - a.(j)) ;
        a.(j) <- a_j' )

  let cond_permute ~params ~permute state =
    let permuted = P.block_cipher params (Array.copy state) in
    for i = 0 to m - 1 do
      state.(i) <- Field.if_ permute ~then_:permuted.(i) ~else_:state.(i)
    done

  let consume_pairs ~params ~state ~pos:start_pos pairs =
    Array.fold ~init:start_pos pairs ~f:(fun p ((b, x), (b', y)) ->
        (* Semantically, we want to do this.
           match b, b' with
           | 1, 1 ->
            if p = 0
            then state := perm {state with .0 += x, .1 += y }
            else state := {perm {state with .1 += x} with .0 += y}
           | 1, 0 ->
            if p = 0
            then state := {state with .0 += x}
            else state := perm {state with .1 += x}
           | 0, 1 ->
            if p = 0
            then state := {state with .0 += y }
            else state := perm {state with .1 += y}
           | 0, 0 ->
            state
        *)
        let p' = Boolean.( lxor ) p b in
        let pos_after = Boolean.( lxor ) p' b' in
        let y = Field.(y * (b' :> t)) in
        let add_in_y_after_perm =
          (* post
             add in
             (1, 1, 1)

             do not add in
             (1, 1, 0)
             (0, 1, 0)
             (0, 1, 1)

             (1, 0, 0)
             (1, 0, 1)
             (0, 0, 0)
             (0, 0, 1)
          *)
          (* Only one case where we add in y after the permutation is applied *)
          Boolean.all [ b; b'; p ]
        in
        let add_in_y_before_perm = Boolean.not add_in_y_after_perm in
        add_in state p Field.(x * (b :> t)) ;
        add_in state p' Field.(y * (add_in_y_before_perm :> t)) ;
        let permute =
          (* (b, b', p)
              true:
              (0, 1, 1)
              (1, 0, 1)
              (1, 1, 0)
              (1, 1, 1)

             false:
              (0, 0, 0)
              (0, 0, 1)
              (0, 1, 0)
              (1, 0, 0)
          *)
          (* (b && b') || (p && (b || b')) *)
          Boolean.(any [ all [ b; b' ]; all [ p; b ||| b' ] ])
        in
        cond_permute ~params ~permute state ;
        add_in state p' Field.(y * (add_in_y_after_perm :> t)) ;
        pos_after )

  let consume ~needs_final_permute_if_empty ~params ~start_pos input state =
    assert (Array.length state = m) ;
    let n = Array.length input in
    let num_pairs = n / 2 in
    let remaining = n - (2 * num_pairs) in
    let pairs =
      Array.init num_pairs ~f:(fun i -> (input.(2 * i), input.((2 * i) + 1)))
    in
    let pos = consume_pairs ~params ~state ~pos:start_pos pairs in
    let empty_imput =
      Boolean.not (Boolean.Array.any (Array.map input ~f:fst))
    in
    let should_permute =
      match remaining with
      | 0 ->
          if needs_final_permute_if_empty then Boolean.(empty_imput ||| pos)
          else pos
      | 1 ->
          let b, x = input.(n - 1) in
          let p = pos in
          let pos_after = Boolean.( lxor ) p b in
          ignore (pos_after : Boolean.var) ;
          add_in state p Field.(x * (b :> t)) ;
          if needs_final_permute_if_empty then Boolean.any [ p; b; empty_imput ]
          else Boolean.any [ p; b ]
      | _ ->
          assert false
    in
    cond_permute ~params ~permute:should_permute state

  let absorb (t : t) x =
    match t.sponge_state with
    | Absorbing { next_index; xs } ->
        t.sponge_state <- Absorbing { next_index; xs = x :: xs }
    | Squeezed _ ->
        t.sponge_state <- Absorbing { next_index = Boolean.false_; xs = [ x ] }

  let squeeze (t : t) =
    match t.sponge_state with
    | Squeezed n ->
        if n = rate then (
          t.state <- block_cipher t.params t.state ;
          t.sponge_state <- Squeezed 1 ;
          t.state.(0) )
        else (
          t.sponge_state <- Squeezed (n + 1) ;
          t.state.(n) )
    | Absorbing { next_index; xs } ->
        consume ~needs_final_permute_if_empty:t.needs_final_permute_if_empty
          ~start_pos:next_index ~params:t.params (Array.of_list_rev xs) t.state ;
        t.needs_final_permute_if_empty <- true ;
        t.sponge_state <- Squeezed 1 ;
        t.state.(0)

  let consume_all_pending (t : t) =
    match t.sponge_state with
    | Squeezed _ ->
        failwith "Nothing pending"
    | Absorbing { next_index; xs } ->
        let input = Array.of_list_rev xs in
        assert (Array.length t.state = m) ;
        let n = Array.length input in
        let num_pairs = n / 2 in
        let remaining = n - (2 * num_pairs) in
        let pairs =
          Array.init num_pairs ~f:(fun i ->
              (input.(2 * i), input.((2 * i) + 1)) )
        in
        let pos =
          consume_pairs ~params:t.params ~state:t.state ~pos:next_index pairs
        in
        let pos_after =
          if remaining = 1 then (
            let b, x = input.(n - 1) in
            let p = pos in
            let pos_after = Boolean.( lxor ) p b in
            add_in t.state p Field.(x * (b :> t)) ;
            pos_after )
          else pos
        in
        (* TODO: We should propagate the emptiness state of the pairs,
           otherwise this will break in some edge cases.
        *)
        t.sponge_state <- Absorbing { next_index = pos_after; xs = [] }

  let recombine ~original_sponge b (t : t) =
    match[@warning "-4"] (original_sponge.sponge_state, t.sponge_state) with
    | Squeezed orig_i, Squeezed curr_i ->
        if orig_i <> curr_i then failwithf "Squeezed %i vs %i" orig_i curr_i () ;
        Array.iteri original_sponge.state ~f:(fun i x ->
            t.state.(i) <- Field.if_ b ~then_:t.state.(i) ~else_:x )
    | ( Absorbing { next_index = next_index_orig; xs = xs_orig }
      , Absorbing { next_index = next_index_curr; xs = xs_curr } ) ->
        (* TODO: Should test for full equality here, if we want to catch all
           sponge misuses.
           OTOH, if you're using this sponge then you'd better know what it's
           doing..
        *)
        if List.length xs_orig <> List.length xs_curr then
          failwithf "Pending absorptions %i vs %i" (List.length xs_orig)
            (List.length xs_curr) () ;
        Array.iteri original_sponge.state ~f:(fun i x ->
            t.state.(i) <- Field.if_ b ~then_:t.state.(i) ~else_:x ) ;
        t.sponge_state <-
          Absorbing
            { next_index =
                Boolean.if_ b ~then_:next_index_curr ~else_:next_index_orig
            ; xs = xs_curr
            }
    | _, _ ->
        failwith "Incompatible states"
end
