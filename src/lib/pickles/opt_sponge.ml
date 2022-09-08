open Core_kernel

(* This module implements snarky functions for a sponge that can *conditionally* absorb input,
   while branching minimally. Specifically, if absorbing N field elements, this sponge can absorb
   a variable subset of N field elements, while performing ceildiv(N, 2) + 1 invocations of the sponge's
   underlying permutation. That is, we only invoke the permutation one more time than we would if not
   doing optional absorption.
*)

(* The state size of our sponge *)
let m = 3

let capacity = 1

(* rate = 2, meaning we can absorb 2 elements per invocation of the permutation *)
let rate = m - capacity

(* An index into the 2 absorbing positions in the 3-element state of Poseidon.
   Such an index is either 0 or 1 and so we represent it using a boolean. *)
type 'f absorb_position_index = 'f Snarky_backendless.Boolean.t

(* This indicates whether we are in an absorbing or squeezing state, plus some
   additional data in each case. *)
type 'f sponge_state =
  | Absorbing of
      { next_index : 'f absorb_position_index
            (* The next index in our 3-element state we should absorb into (either 0 or 1) *)
      ; xs : ('f Snarky_backendless.Boolean.t * 'f) list
            (* The list of (should actually absorb, field element) pairs that we've conditionally
               absorbed so far, in reverse order so that we can "append" to the front.

               Our strategy is kind of lazy. We defer doing any actual computation until [squeeze]
               is called and absorb by simply consing onto this list.
            *)
      }
  | Squeezed of int
(* How many elements have we squeezed from the sponge. *)

type 'f t =
  { mutable state : 'f array (* The underlying Poseidon state *)
  ; params : 'f Sponge.Params.t
        (* Poseidon parameters (round constants and MDS matrix) *)
  ; needs_final_permute_if_empty : bool
        (* A flag indicating that the sponge needs to be permuted even when none of the
           optional inputs are absorbed. This is the case if we create an opt-sponge from
           a standard sponge that has already absorbed some inputs. *)
  ; mutable sponge_state : 'f sponge_state
        (* The absorption state of the sponge. *)
  }

module Make
    (Impl : Snarky_backendless.Snark_intf.Run)
    (P : Sponge.Intf.Permutation with type Field.t = Impl.Field.t) =
struct
  open P
  open Impl

  type nonrec t = Field.t t

  let state { state; _ } = Array.copy state

  let copy { state; params; sponge_state; needs_final_permute_if_empty } =
    { state = Array.copy state
    ; params
    ; sponge_state
    ; needs_final_permute_if_empty
    }

  type absorb_position_index = Boolean.var

  (* Create an opt-sponge from a normal sponge *)
  let of_sponge { Sponge.state; params; sponge_state } =
    match sponge_state with
    | Squeezed n ->
        { sponge_state = Squeezed n
        ; state = Array.copy state
        ; needs_final_permute_if_empty = true
        ; params
        }
    | Absorbed n -> (
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

  let initial_state = Array.init m ~f:(fun _ -> Field.zero)

  (* Create an opt-sponge from a set of parameters and an optional initial state. *)
  let create ?(init = initial_state) params =
    { params
    ; state = Array.copy init
    ; needs_final_permute_if_empty = true
    ; sponge_state = Absorbing { next_index = Boolean.false_; xs = [] }
    }

  let () = assert (rate = 2)

  (* Given an array of field element variables [a] of length 2, a variable index [i] (which is a [Boolean.var])
     and a field element variable [x], set [a.(i)] to [a.(i) + x].

     Note that the trickiness is that [i] is a variable and not an [int]. *)
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

  (* Absorb an array of optional inputs [input: (absorb_position_index * Field.t) array]
     into the sponge with state [state : Field.t array], starting to absorb at
     index [start_pos : absorb_position_index].

     And, if [needs_final_permute_if_empty], apply the permutation a final time
     at the end if all of the optional inputs were not present. *)
  let consume ~(params : Field.t Sponge.Params.t)
      ~(needs_final_permute_if_empty : bool)
      ~(start_pos : absorb_position_index) (state : Field.t array)
      (input : (absorb_position_index * Field.t) array) =
    assert (Array.length state = m) ;
    let n = Array.length input in
    let pos = ref start_pos in
    let cond_permute permute =
      let permuted = P.block_cipher params (Array.copy state) in
      for i = 0 to m - 1 do
        state.(i) <- Field.if_ permute ~then_:permuted.(i) ~else_:state.(i)
      done
    in
    let pairs = n / 2 in
    let remaining = n - (2 * pairs) in
    for i = 0 to pairs - 1 do
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
      let b, x = input.(2 * i) in
      let b', y = input.((2 * i) + 1) in
      let p = !pos in
      let p' = Boolean.( lxor ) p b in
      pos := Boolean.( lxor ) p' b' ;
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
      cond_permute permute ;
      add_in state p' Field.(y * (add_in_y_after_perm :> t))
    done ;
    (* True iff all of the inputs are "None", i.e., if all the flags are false. *)
    let empty_imput =
      Boolean.not (Boolean.Array.any (Array.map input ~f:fst))
    in
    let should_permute =
      match remaining with
      | 0 ->
          if needs_final_permute_if_empty then Boolean.(empty_imput ||| !pos)
          else !pos
      | 1 ->
          let b, x = input.(n - 1) in
          let p = !pos in
          pos := Boolean.( lxor ) p b ;
          add_in state p Field.(x * (b :> t)) ;
          if needs_final_permute_if_empty then Boolean.any [ p; b; empty_imput ]
          else Boolean.any [ p; b ]
      | _ ->
          assert false
    in
    cond_permute should_permute

  (* Absorb a value into the opt-sponge. This we do by simply prepending to
     a list, deferring the actual computation until "squeeze" is called. *)
  let absorb (t : t) x =
    match t.sponge_state with
    | Absorbing { next_index; xs } ->
        t.sponge_state <- Absorbing { next_index; xs = x :: xs }
    | Squeezed _ ->
        t.sponge_state <- Absorbing { next_index = Boolean.false_; xs = [ x ] }

  (* Squeeze a value from the opt-sponge. *)
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
          ~start_pos:next_index ~params:t.params t.state (Array.of_list_rev xs) ;
        t.sponge_state <- Squeezed 1 ;
        t.state.(0)

  let%test_module "opt_sponge" =
    ( module struct
      module S = Sponge.Make_sponge (P)

      let%test_unit "correctness" =
        let params : _ Sponge.Params.t =
          let a () =
            Array.init 3 ~f:(fun _ -> Field.(constant (Constant.random ())))
          in
          { mds = Array.init 3 ~f:(fun _ -> a ())
          ; round_constants = Array.init 40 ~f:(fun _ -> a ())
          }
        in
        let gen =
          let open Quickcheck.Generator.Let_syntax in
          let%bind n = Quickcheck.Generator.small_positive_int
          and n_pre = Quickcheck.Generator.small_positive_int in
          let%map xs = List.gen_with_length n Field.Constant.gen
          and bs = List.gen_with_length n Bool.quickcheck_generator
          and pre = List.gen_with_length n_pre Field.Constant.gen in
          (pre, List.zip_exn bs xs)
        in
        Quickcheck.test gen ~trials:10 ~f:(fun (pre, ps) ->
            let filtered =
              List.filter_map ps ~f:(fun (b, x) -> if b then Some x else None)
            in
            let init () =
              let pre =
                exists
                  (Typ.list ~length:(List.length pre) Field.typ)
                  ~compute:(fun () -> pre)
              in
              let s = S.create params in
              List.iter pre ~f:(S.absorb s) ;
              s
            in
            let filtered_res =
              let n = List.length filtered in
              Impl.Internal_Basic.Test.checked_to_unchecked
                (Typ.list ~length:n Field.typ)
                Field.typ
                (fun xs ->
                  make_checked (fun () ->
                      let s = init () in
                      List.iter xs ~f:(S.absorb s) ;
                      S.squeeze s ) )
                filtered
            in
            let opt_res =
              let n = List.length ps in
              Impl.Internal_Basic.Test.checked_to_unchecked
                (Typ.list ~length:n (Typ.tuple2 Boolean.typ Field.typ))
                Field.typ
                (fun xs ->
                  make_checked (fun () ->
                      let s =
                        if List.length pre = 0 then create params
                        else of_sponge (init ())
                      in
                      List.iter xs ~f:(absorb s) ;
                      squeeze s ) )
                ps
            in
            if not (Field.Constant.equal filtered_res opt_res) then
              failwithf
                !"hash(%{sexp:Field.Constant.t list}) = %{sexp:Field.Constant.t}\n\
                  hash(%{sexp:(bool * Field.Constant.t) list}) = \
                  %{sexp:Field.Constant.t}"
                filtered filtered_res ps opt_res () )
    end )
end
