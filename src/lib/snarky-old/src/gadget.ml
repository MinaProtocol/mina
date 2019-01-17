open Core

module Make
    (Impl : Snark_intf.S)
    (Libsnark : Libsnark.S
                with type Field.t = Impl.Field.t
                 and type Var.t = Impl.Var.t
                 and type Field.Vector.t = Impl.Field.Vector.t
                 and type R1CS_constraint_system.t =
                            Impl.R1CS_constraint_system.t) (M : sig
        type t

        type input

        type witness

        val generate_witness :
          t -> input -> witness -> (unit, _) Impl.As_prover.t

        val create :
             Libsnark.Protoboard.t
          -> (Impl.Field.Checked.t -> Libsnark.Protoboard.Variable.t)
          -> (Libsnark.Protoboard.Variable.t -> Impl.Field.Checked.t)
          -> input
          -> t

        val generate_constraints : t -> unit
    end) =
struct
  open Impl
  module Protoboard = Libsnark.Protoboard
  module Var = Libsnark.Var
  module R1CS_constraint_system = Libsnark.R1CS_constraint_system
  module Linear_combination = Libsnark.Linear_combination

  let create input get_witness =
    let pb = Protoboard.create () in
    let lcs = Linear_combination.Vector.create () in
    let num_input_vars = ref 0 in
    let var_pairs = ref [] in
    let conv cvar =
      let c, terms = Field.Checked.to_constant_and_terms cvar in
      let lc =
        match c with
        | None -> Linear_combination.create ()
        | Some c -> Linear_combination.of_field c
      in
      List.iter terms ~f:(fun (x, v) -> Linear_combination.add_term lc x v) ;
      Linear_combination.Vector.emplace_back lcs lc ;
      let var = Protoboard.allocate_variable pb in
      incr num_input_vars ;
      var_pairs := (cvar, var) :: !var_pairs ;
      var
    in
    let open Let_syntax in
    let%bind next_aux = next_auxiliary in
    let conv_back pb_var =
      let i = Protoboard.Variable.index pb_var in
      let num_input = !num_input_vars in
      if i < num_input then
        failwithf "Cannot convert back %d (%d)" i num_input () ;
      let shift = next_aux - num_input - 1 in
      (* TODO-soon: This is slightly hacky ATM and requires the caller only call
         conv_back after they are done calling conv. Please make this staging explicit in
         the types. *)
      Impl.Field.Checked.Unsafe.of_var
        (Var.create (Protoboard.Variable.index pb_var + shift))
    in
    let t = M.create pb conv conv_back input in
    let () = Protoboard.set_input_sizes pb !num_input_vars in
    let num_aux_vars = Protoboard.num_variables pb - !num_input_vars in
    let%bind () =
      with_constraint_system (fun sys ->
          M.generate_constraints t ;
          Protoboard.renumber_and_append_constraints pb sys lcs
            (next_aux - !num_input_vars - 1) )
    in
    let%map () =
      let%bind () =
        as_prover
          (let open As_prover in
          let open Let_syntax in
          let rec go = function
            | [] -> return ()
            | (cv, v) :: ps ->
                let%bind x = read_var cv in
                Protoboard.set_variable pb v x ;
                go ps
          in
          let%bind () = go !var_pairs in
          let%bind w = get_witness in
          M.generate_witness t input w)
      in
      let ap thunk = As_prover.(map (return ()) ~f:thunk) in
      with_state
        (ap (fun () -> Protoboard.auxiliary_input pb))
        (let rec go i =
           if i = num_aux_vars then return ()
           else
             let%bind _ =
               exists Typ.field
                 ~compute:
                   As_prover.(map get_state ~f:(fun v -> Field.Vector.get v i))
             in
             go (i + 1)
         in
         go 0)
    in
    t
end
