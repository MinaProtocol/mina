open Core
open Snarky
open Zexe_backend_common.Plonk_plookup_constraint_system

module ArithmeticSponge
    (Intf : Snark_intf.Run with type prover_state = unit)
    (Params : sig val params : Intf.field Sponge.Params.t end)
= struct
  open Intf

  type sponge_state = Absorbed of int | Squeezed of int [@@deriving sexp]
  let rate = 4

  type 'f t =
    { mutable state: 'f Array.t
    ; mutable sponge_state: sponge_state }

  let st: Field.t t = {state = Array.init 5 ~f:(fun _ -> Field.zero); sponge_state= Absorbed 0;}

  let add_assign ~state i x = Field.(state.(i) <- (state.(i) + x))

  let permute (start : Field.t array) rounds : Field.t array =
    let length = Array.length start in
    let state = exists
        (Snarky.Typ.array ~length:Int.(rounds + 1) (Snarky.Typ.array length Field.typ))
        ~compute:As_prover.(fun () ->
            (
              let state = Array.create Int.(rounds + 1) (Array.create length zero) in
              state.(0) <- Array.map ~f:(fun x -> read_var x) start;
              for i = 1 to rounds do
                state.(i) <- Array.map ~f:(fun x -> (let sq = square x in (square sq) * sq * x)) state.(Int.(i-1));
                state.(i) <- Array.map
                    ~f:(fun p -> Array.fold2_exn p state.(i) ~init:Field.Constant.zero ~f:(fun c a b -> a * b + c))
                    Params.params.mds;
                for j = 0 to Int.(length - 1) do
                  state.(i).(j) <- state.(i).(j) + Params.params.round_constants.(Int.(i - 1)).(j)
                done;
              done;
              state
            ))
    in
    state.(0) <- start;
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Poseidon { state }) ;
        annotation= Some "plonk-poseidon"
      }];
    state.(rounds)

  let block_cipher (start : Field.t array) : Field.t array =
    permute start 57

  let absorb x =
    match st.sponge_state with
    | Absorbed n ->
        if n = rate then (
          st.state <- block_cipher st.state ;
          add_assign ~state:st.state 0 x ;
          st.sponge_state <- Absorbed 1 )
        else (
          add_assign ~state:st.state n x ;
          st.sponge_state <- Absorbed (n + 1) )
    | Squeezed _ ->
        add_assign ~state:st.state 0 x ;
        st.sponge_state <- Absorbed 1

  let squeeze () =
    match st.sponge_state with
    | Squeezed n ->
        if n = rate then (
          st.state <- block_cipher st.state ;
          st.sponge_state <- Squeezed 1 ;
          st.state.(0) )
        else (
          st.sponge_state <- Squeezed (n + 1) ;
          st.state.(n) )
    | Absorbed _ ->
        st.state <- block_cipher st.state ;
        st.sponge_state <- Squeezed 1 ;
        st.state.(0)
end
