open Core

module Make
    (Impl : Snark_intf.S)
    (Main_libsnark : Libsnark.S
                     with type Field.t = Impl.Field.t
                      and type Var.t = Impl.Var.t
                      and type Field.Vector.t = Impl.Field.Vector.t
                      and type R1CS_constraint_system.t =
                                 Impl.R1CS_constraint_system.t)
    (Other_curve : Libsnark.S) (Info : sig
        val input_size : int
    end) =
struct
  open Impl
  open Ctypes
  open Foreign
  module Libsnark = Main_libsnark
  module Pb = Libsnark.Protoboard

  let suspend f = As_prover.(map (return ()) ~f)

  let with_prefix = sprintf "%s_%s"

  module Verification_key = struct
    type t = unit ptr

    type input = Boolean.var list

    type witness = Other_curve.Verification_key.t

    let typ = ptr void

    let prefix =
      with_prefix Main_libsnark.prefix
        "r1cs_ppzksnark_verification_key_variable"

    let func_name = with_prefix prefix

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let conv_input conv (all_bits : input) =
      let bits = Pb.Variable_array.create () in
      List.iter all_bits ~f:(fun b ->
          Pb.Variable_array.emplace_back bits (conv (b :> Field.Checked.t)) ) ;
      bits

    let create =
      let stub =
        foreign (func_name "create")
          (Pb.typ @-> Pb.Variable_array.typ @-> int @-> returning typ)
      in
      fun pb (conv : Field.Checked.t -> Pb.Variable.t)
          (bits : Pb.Variable_array.t) ->
        let t = stub pb bits Info.input_size in
        Caml.Gc.finalise delete t ; t

    let generate_constraints =
      foreign (func_name "generate_r1cs_constraints") (typ @-> returning void)

    let generate_witness_stub =
      foreign
        (func_name "generate_r1cs_witness")
        (typ @-> Other_curve.Verification_key.typ @-> returning void)

    let generate_witness t _input witness =
      suspend (fun () -> generate_witness_stub t witness)

    let to_field_list =
      let stub =
        foreign
          (with_prefix Main_libsnark.prefix
             "verification_key_other_to_field_vector")
          (Other_curve.Verification_key.typ @-> returning Field.Vector.typ)
      in
      fun k ->
        let v = stub k in
        let xs =
          List.init (Field.Vector.length v) ~f:(fun i -> Field.Vector.get v i)
        in
        Field.Vector.delete v ; xs

    let to_bit_vector =
      let stub =
        foreign
          (with_prefix Main_libsnark.prefix
             "verification_key_other_to_bool_vector")
          (Other_curve.Verification_key.typ @-> returning Bool_vector.typ)
      in
      fun k ->
        let v = stub k in
        Caml.Gc.finalise Bool_vector.delete v ;
        v

    let to_bool_list k =
      let v = to_bit_vector k in
      List.init (Bool_vector.length v) ~f:(fun i -> Bool_vector.get v i)
  end

  module Proof = struct
    type t = unit ptr

    type input = unit

    type witness = Other_curve.Proof.t

    let typ = ptr void

    let prefix =
      with_prefix Main_libsnark.prefix "r1cs_ppzksnark_proof_variable"

    let func_name = with_prefix prefix

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let create =
      let stub = foreign (func_name "create") (Pb.typ @-> returning typ) in
      fun pb _conv _conv_back () ->
        let t = stub pb in
        Caml.Gc.finalise delete t ; t

    let generate_constraints =
      foreign (func_name "generate_r1cs_constraints") (typ @-> returning void)

    let generate_witness_stub =
      foreign
        (func_name "generate_r1cs_witness")
        (typ @-> Other_curve.Proof.typ @-> returning void)
  end

  module T = struct
    type t = {gadget: unit ptr; result: Field.Checked.t}

    let typ = ptr void

    type input =
      { vk: Verification_key.t
      ; input: Boolean.var list
      ; elt_size: int
      ; proof: Proof.t }

    type witness = unit

    let prefix =
      with_prefix Main_libsnark.prefix "r1cs_ppzksnark_verifier_gadget"

    let func_name = with_prefix prefix

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let create_stub =
      foreign (func_name "create")
        ( Pb.typ @-> Verification_key.typ @-> Pb.Variable_array.typ @-> int
        @-> Proof.typ @-> Pb.Variable.typ @-> returning typ )

    let create pb (conv : Field.Checked.t -> Pb.Variable.t)
        (conv_back : Pb.Variable.t -> Field.Checked.t)
        {vk; input; elt_size; proof} =
      let input_pb = Pb.Variable_array.create () in
      List.iter
        ~f:(fun v -> Pb.Variable_array.emplace_back input_pb (conv v))
        (input :> Field.Checked.t list) ;
      let result_pb = Pb.allocate_variable pb in
      let result = conv_back result_pb in
      let t = create_stub pb vk input_pb elt_size proof result_pb in
      Caml.Gc.finalise delete t ; {gadget= t; result}

    let generate_constraints =
      let stub =
        foreign (func_name "generate_r1cs_constraints") (typ @-> returning void)
      in
      fun {gadget; _} -> stub gadget

    let generate_witness_stub =
      foreign (func_name "generate_r1cs_witness") (typ @-> returning void)

    let generate_witness {gadget; _} _input () =
      suspend (fun () -> generate_witness_stub gadget)
  end

  module All_in_one = struct
    module T = struct
      type t = {verifier: T.t; vk: Verification_key.t; proof: Proof.t}

      let typ = T.typ

      type input = {vk_bits: Boolean.var list; input: Boolean.var list}

      type witness =
        { verification_key: Other_curve.Verification_key.t
        ; proof: Other_curve.Proof.t }

      let elt_size = Other_curve.Field.size_in_bits

      let create pb conv conv_back {vk_bits; input} =
        printf "Converting vk_bits\n%!" ;
        let vk_bits_arr = Verification_key.conv_input conv vk_bits in
        let input_pb = Pb.Variable_array.create () in
        printf "next converting input bits\n%!" ;
        List.iter
          ~f:(fun v -> Pb.Variable_array.emplace_back input_pb (conv v))
          (input :> Field.Checked.t list) ;
        let vk = Verification_key.create pb conv vk_bits_arr in
        let proof = Proof.create pb conv conv_back () in
        let result_pb = Pb.allocate_variable pb in
        let t = T.create_stub pb vk input_pb elt_size proof result_pb in
        let result = conv_back result_pb in
        Caml.Gc.finalise T.delete t ;
        {verifier= {gadget= t; result}; vk; proof}

      let generate_constraints {verifier; vk; proof} =
        Verification_key.generate_constraints vk ;
        Proof.generate_constraints proof ;
        T.generate_constraints verifier

      let generate_witness {verifier; vk; proof} _input
          {verification_key; proof= proof_val} =
        suspend (fun () ->
            Verification_key.generate_witness_stub vk verification_key ;
            Proof.generate_witness_stub proof proof_val ;
            T.generate_witness_stub verifier.gadget )
    end

    include T
    include Gadget.Make (Impl) (Main_libsnark) (T)

    let create ~verification_key ~input get_witness =
      create {vk_bits= verification_key; input} get_witness

    let result {T.verifier= {result}} = Boolean.Unsafe.of_cvar result
  end
end

module Mnt4
    (Impl : Snark_intf.S
            with type field = Libsnark.Mnt4.Field.t
             and type Var.t = Libsnark.Mnt4.Var.t
             and type Field.Vector.t = Libsnark.Mnt4.Field.Vector.t
             and type R1CS_constraint_system.t =
                        Libsnark.Mnt4.R1CS_constraint_system.t) (Info : sig
        val input_size : int
    end) =
  Make (Impl) (Libsnark.Mnt4.Default) (Libsnark.Mnt6.Default) (Info)
module Mnt6
    (Impl : Snark_intf.S
            with type field = Libsnark.Mnt6.Field.t
             and type Var.t = Libsnark.Mnt6.Var.t
             and type Field.Vector.t = Libsnark.Mnt6.Field.Vector.t
             and type R1CS_constraint_system.t =
                        Libsnark.Mnt6.R1CS_constraint_system.t) (Info : sig
        val input_size : int
    end) =
  Make (Impl) (Libsnark.Mnt6.Default) (Libsnark.Mnt4.Default) (Info)
