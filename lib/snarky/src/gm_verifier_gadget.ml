open Core

module Make
    (Impl : Snark_intf.S) (Prefix : sig
        val prefix : string
    end)
    (Main_libsnark : Libsnark.S
                     with type Field.t = Impl.Field.t
                      and type Var.t = Impl.Var.t
                      and type Field.Vector.t = Impl.Field.Vector.t
                      and type R1CS_constraint_system.t =
                                 Impl.R1CS_constraint_system.t)
    (Other_curve : Libsnark.S) (Info : sig
        val input_size : int

        val fqe_size_in_field_elements : int
    end) =
struct
  open Impl
  open Ctypes
  open Foreign
  module Libsnark = Main_libsnark
  module Pb = Libsnark.Protoboard

  let suspend f = As_prover.(map (return ()) ~f)

  let with_prefix = sprintf "%s_%s"

  module G1_variable = struct
    type t = unit ptr
  end

  module Verification_key : sig
    type t

    val typ : t Ctypes.typ

    val create : Pb.t -> t

    val characterizing_vars_up_to_sign :
      t -> Libsnark.Linear_combination.Vector.t

    val sign_vars : t -> Libsnark.Linear_combination.Vector.t

    val characterizing_elts_up_to_sign :
      Other_curve.Verification_key.t -> Field.Vector.t

    val sign_elts : Other_curve.Verification_key.t -> Field.Vector.t

    val generate_witness : t -> Other_curve.Verification_key.t -> unit
  end = struct
    (* Verification_key
       -> (array of G1 vars -> array of xs * array of ys *)
    type t = unit ptr

    let typ = ptr void

    type witness = Other_curve.Verification_key.t

    let prefix =
      with_prefix Prefix.prefix "r1cs_se_ppzksnark_verification_key_variable"

    let func_name = with_prefix prefix

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let create =
      let stub =
        foreign (func_name "create") (Pb.typ @-> int @-> returning typ)
      in
      fun pb ->
        let t = stub pb Info.input_size in
        Caml.Gc.finalise delete t ; t

    let generate_witness =
      foreign
        (func_name "generate_r1cs_witness")
        (typ @-> Other_curve.Verification_key.typ @-> returning void)

    let characterizing_elts_up_to_sign =
      let stub =
        foreign
          (with_prefix Prefix.prefix
             "gm_verification_key_characterizing_elts_up_to_sign")
          (Other_curve.Verification_key.typ @-> returning Field.Vector.typ)
      in
      fun t ->
        let v = stub t in
        Caml.Gc.finalise Field.Vector.delete v ;
        v

    let sign_elts =
      let stub =
        foreign
          (with_prefix Prefix.prefix "gm_verification_key_sign_elts")
          (Other_curve.Verification_key.typ @-> returning Field.Vector.typ)
      in
      fun t ->
        let v = stub t in
        Caml.Gc.finalise Field.Vector.delete v ;
        v

    let characterizing_vars_up_to_sign =
      let stub =
        foreign
          (func_name "characterizing_vars_up_to_sign")
          (typ @-> returning Libsnark.Linear_combination.Vector.typ)
      in
      fun t ->
        let res = stub t in
        Caml.Gc.finalise Libsnark.Linear_combination.Vector.delete res ;
        res

    let sign_vars =
      let stub =
        foreign (func_name "sign_vars")
          (typ @-> returning Libsnark.Linear_combination.Vector.typ)
      in
      fun t ->
        let res = stub t in
        Caml.Gc.finalise Libsnark.Linear_combination.Vector.delete res ;
        res
  end

  module Verification_key_data = struct
    type 'field t_ = {characterizing_up_to_sign: 'field list; sign: 'field list}
    [@@deriving sexp]

    let characterizing_length, sign_length =
      let g1_count = 2 + (1 + Info.input_size) in
      let g2_count = 3 in
      let gt_count = 1 in
      ( (g1_count * 1)
        + (g2_count * Info.fqe_size_in_field_elements)
        + (gt_count * Info.fqe_size_in_field_elements)
      , g1_count + g2_count + gt_count )

    type t = Field.t t_ [@@deriving sexp]

    type var = Field.Checked.t t_

    let bit_length = (characterizing_length * Field.size_in_bits) + sign_length

    let typ =
      let open H_list in
      Typ.of_hlistable
        [ Typ.list ~length:characterizing_length Field.typ
        ; Typ.list ~length:sign_length Field.typ ]
        ~var_to_hlist:(fun {characterizing_up_to_sign; sign} ->
          [characterizing_up_to_sign; sign] )
        ~value_to_hlist:(fun {characterizing_up_to_sign; sign} ->
          [characterizing_up_to_sign; sign] )
        ~var_of_hlist:(fun [characterizing_up_to_sign; sign] ->
          {characterizing_up_to_sign; sign} )
        ~value_of_hlist:(fun [characterizing_up_to_sign; sign] ->
          {characterizing_up_to_sign; sign} )

    let of_verification_key vk : t =
      let elts = Verification_key.characterizing_elts_up_to_sign vk in
      let signs = Verification_key.sign_elts vk in
      let module V = Field.Vector in
      assert (V.length elts = characterizing_length) ;
      assert (V.length signs = sign_length) ;
      { characterizing_up_to_sign=
          List.init (V.length elts) ~f:(fun i -> V.get elts i)
      ; sign= List.init (V.length signs) ~f:(fun i -> V.get signs i) }

    let to_bits ({characterizing_up_to_sign; sign} as t: t) =
      printf !"To bits: %{sexp:t}\n%!" t ;
      let bs1 =
        (* It's ok to use choose_preimage here *)
        List.concat_map characterizing_up_to_sign ~f:(fun x -> Field.unpack x)
      and bs2 =
        (* but not here *)
        List.map sign ~f:(fun x ->
            assert (not (Field.equal Field.zero x)) ;
            Bigint.test_bit (Bigint.of_field x) 0 )
      in
      bs1 @ bs2

    module Checked = struct
      let constant ({sign; characterizing_up_to_sign}: t) : var =
        { sign= List.map sign ~f:Field.Checked.constant
        ; characterizing_up_to_sign=
            List.map characterizing_up_to_sign ~f:Field.Checked.constant }

      module Assert = struct
        let equal t1 t2 =
          let check xs ys =
            Checked.List.iter (List.zip_exn xs ys) ~f:(fun (x, y) ->
                Field.Checked.Assert.equal x y )
          in
          let open Checked.Let_syntax in
          let%map () =
            check t1.characterizing_up_to_sign t2.characterizing_up_to_sign
          and () = check t1.sign t2.sign in
          ()
      end

      let to_bits ({characterizing_up_to_sign; sign}: var) =
        let open Checked.Let_syntax in
        let%map bs1 =
          (* It's ok to use choose_preimage here *)
          Checked.List.map characterizing_up_to_sign ~f:(fun x ->
              Field.Checked.choose_preimage_var x ~length:Field.size_in_bits )
          >>| List.concat
        and bs2 =
          (* but not here *)
          Checked.List.map sign ~f:(fun x ->
              let%bind () = Field.Checked.Assert.non_zero x in
              Field.Checked.unpack_full x
              >>| Bitstring_lib.Bitstring.Lsb_first.to_list >>| List.hd_exn )
        in
        bs1 @ bs2
    end
  end

  module Preprocessed_verification_key = struct
    type t = unit ptr

    let typ = ptr void

    let prefix =
      with_prefix Prefix.prefix
        "r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable"

    let func_name = with_prefix prefix

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let create =
      let stub = foreign (func_name "create") (void @-> returning typ) in
      fun () ->
        let t = stub () in
        Caml.Gc.finalise delete t ; t

    let create_known =
      let stub =
        foreign (func_name "create_known")
          (Pb.typ @-> Other_curve.Verification_key.typ @-> returning typ)
      in
      fun pb vk ->
        let t = stub pb vk in
        Caml.Gc.finalise delete t ; t
  end

  module Proof : sig
    type t

    val typ : t Ctypes.typ

    val generate_constraints : t -> unit

    val generate_witness : t -> Other_curve.Proof.t -> unit

    val create : Pb.t -> t
  end = struct
    type t = unit ptr

    type input = unit

    type witness = Other_curve.Proof.t

    let typ = ptr void

    let prefix = with_prefix Prefix.prefix "r1cs_se_ppzksnark_proof_variable"

    let func_name = with_prefix prefix

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let create =
      let stub = foreign (func_name "create") (Pb.typ @-> returning typ) in
      fun pb ->
        let t = stub pb in
        Caml.Gc.finalise delete t ; t

    let generate_constraints =
      foreign (func_name "generate_r1cs_constraints") (typ @-> returning void)

    let generate_witness =
      foreign
        (func_name "generate_r1cs_witness")
        (typ @-> Other_curve.Proof.typ @-> returning void)
  end

  module Online_verifier = struct
    type gadget = unit ptr

    let gadget_typ = ptr void

    type t = {gadget: gadget; result: Field.Checked.t}

    type input =
      { pvk: Preprocessed_verification_key.t
      ; input: Boolean.var list
      ; elt_size: int
      ; proof: Proof.t }

    type witness = unit

    let prefix =
      with_prefix Prefix.prefix "r1cs_se_ppzksnark_online_verifier_gadget"

    let func_name = with_prefix prefix

    let delete = foreign (func_name "delete") (gadget_typ @-> returning void)

    let create_stub =
      foreign (func_name "create")
        ( Pb.typ @-> Preprocessed_verification_key.typ @-> Pb.Variable_array.typ
        @-> int @-> Proof.typ @-> Pb.Variable.typ @-> returning gadget_typ )

    let create pb (conv: Field.Checked.t -> Pb.Variable.t)
        (conv_back: Pb.Variable.t -> Field.Checked.t)
        {pvk; input; elt_size; proof} =
      let input_pb = Pb.Variable_array.create () in
      List.iter
        ~f:(fun v -> Pb.Variable_array.emplace_back input_pb (conv v))
        (input :> Field.Checked.t list) ;
      let result_pb = Pb.allocate_variable pb in
      let gadget = create_stub pb pvk input_pb elt_size proof result_pb in
      Caml.Gc.finalise delete gadget ;
      let result = conv_back result_pb in
      {gadget; result}

    let generate_constraints =
      let stub =
        foreign
          (func_name "generate_r1cs_constraints")
          (gadget_typ @-> returning void)
      in
      fun {gadget; _} -> stub gadget

    let generate_witness_stub =
      foreign
        (func_name "generate_r1cs_witness")
        (gadget_typ @-> returning void)

    let generate_witness {gadget; _} _input () =
      suspend (fun () -> generate_witness_stub gadget)
  end

  module All_in_one = struct
    module T = struct
      type gadget = unit ptr

      let gadget_typ = ptr void

      let prefix =
        with_prefix Prefix.prefix "r1cs_se_ppzksnark_verifier_gadget"

      let func_name = with_prefix prefix

      type t =
        { gadget: gadget
        ; vk: Verification_key.t
        ; proof: Proof.t
        ; result: Boolean.var
        ; vk_characterizing_vars_up_to_sign: Field.Checked.t list
        ; vk_sign_vars: Field.Checked.t list }

      type input = Boolean.var list

      type witness =
        { verification_key: Other_curve.Verification_key.t
        ; proof: Other_curve.Proof.t }

      let delete_gadget =
        foreign (func_name "delete") (gadget_typ @-> returning void)

      let elt_size = Other_curve.Field.size_in_bits

      let create_gadget =
        let stub =
          foreign (func_name "create")
            ( Pb.typ @-> Verification_key.typ @-> Pb.Variable_array.typ @-> int
            @-> Proof.typ @-> Pb.Variable.typ @-> returning gadget_typ )
        in
        fun pb vk input_pb proof result_pb ->
          let gadget = stub pb vk input_pb elt_size proof result_pb in
          Caml.Gc.finalise delete_gadget gadget ;
          gadget

      let gadget_generate_constraints =
        foreign
          (func_name "generate_r1cs_constraints")
          (gadget_typ @-> returning void)

      let gadget_generate_witness =
        foreign
          (func_name "generate_r1cs_witness")
          (gadget_typ @-> returning void)

      let conv_term conv_back term =
        let open Libsnark.Linear_combination in
        let var = Pb.Variable.of_int (Libsnark.Var.index (Term.var term)) in
        let coeff = Term.coeff term in
        Field.Checked.scale (conv_back var) coeff

      let conv_lc conv_back lc =
        let open Libsnark.Linear_combination in
        let terms = terms lc in
        let n = Term.Vector.length terms in
        if Int.equal n 0 then Field.Checked.constant Field.zero
        else
          let rec go i acc =
            if Int.equal i n then acc
            else
              let term = Term.Vector.get terms i in
              let acc = Field.Checked.add (conv_term conv_back term) acc in
              go (i + 1) acc
          in
          go 1 (conv_term conv_back (Term.Vector.get terms 0))

      let conv_lc_vector conv_back lcs =
        let module V = Libsnark.Linear_combination.Vector in
        List.init (V.length lcs) ~f:(fun i -> conv_lc conv_back (V.get lcs i))

      let create pb conv conv_back (input: input) =
        let input_pb =
          let res = Pb.Variable_array.create () in
          List.iter input ~f:(fun b ->
              Pb.Variable_array.emplace_back res (conv (b :> Field.Checked.t))
          ) ;
          res
        in
        let vk = Verification_key.create pb in
        let proof = Proof.create pb in
        let result_pb = Pb.allocate_variable pb in
        let gadget = create_gadget pb vk input_pb proof result_pb in
        let result = conv_back result_pb in
        let vk_characterizing_vars_up_to_sign =
          conv_lc_vector conv_back
            (Verification_key.characterizing_vars_up_to_sign vk)
        in
        let vk_sign_vars =
          conv_lc_vector conv_back (Verification_key.sign_vars vk)
        in
        { gadget
        ; vk
        ; proof
        ; result= Boolean.Unsafe.of_cvar result
        ; vk_sign_vars
        ; vk_characterizing_vars_up_to_sign }

      let generate_constraints {gadget; proof; _} =
        Proof.generate_constraints proof ;
        gadget_generate_constraints gadget

      let generate_witness {gadget; proof; vk; _} _input (w: witness) =
        suspend (fun () ->
            Verification_key.generate_witness vk w.verification_key ;
            Proof.generate_witness proof w.proof ;
            gadget_generate_witness gadget )
    end

    include T
    include Gadget.Make (Impl) (Libsnark) (T)

    let choose_verification_key_data_and_proof_and_check_result input
        get_witness =
      let open Let_syntax in
      let%map t = create input get_witness in
      assert (
        List.length t.vk_characterizing_vars_up_to_sign
        = Verification_key_data.characterizing_length ) ;
      assert (List.length t.vk_sign_vars = Verification_key_data.sign_length) ;
      ( { Verification_key_data.characterizing_up_to_sign=
            t.vk_characterizing_vars_up_to_sign
        ; sign= t.vk_sign_vars }
      , t.result )
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
  Make (Impl)
    (struct
      let prefix = "camlsnark_mnt4"
    end)
    (Libsnark.Mnt4.GM)
    (Libsnark.Mnt6.GM)
    (struct
      include Info

      let fqe_size_in_field_elements = 3
    end)

module Mnt6
    (Impl : Snark_intf.S
            with type field = Libsnark.Mnt6.Field.t
             and type Var.t = Libsnark.Mnt6.Var.t
             and type Field.Vector.t = Libsnark.Mnt6.Field.Vector.t
             and type R1CS_constraint_system.t =
                        Libsnark.Mnt6.R1CS_constraint_system.t) (Info : sig
        val input_size : int
    end) =
  Make (Impl)
    (struct
      let prefix = "camlsnark_mnt6"
    end)
    (Libsnark.Mnt6.GM)
    (Libsnark.Mnt4.GM)
    (struct
      include Info

      let fqe_size_in_field_elements = 2
    end)
