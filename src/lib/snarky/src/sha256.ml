open Core
open Tuple_lib
open Fold_lib

module Make (Prefix : sig
  val prefix : string
end)
(Impl : Snark_intf.S)
(Libsnark : Libsnark.S
            with type Field.t = Impl.Field.t
             and type Var.t = Impl.Var.t
             and type Field.Vector.t = Impl.Field.Vector.t
             and type R1CS_constraint_system.t = Impl.R1CS_constraint_system.t) : sig
  open Impl

  module Digest : sig
    type t = bool list [@@deriving sexp, bin_io, eq, compare]

    type var = Boolean.var list

    val length_in_bits : int

    val typ : (var, t) Typ.t

    val fold : t -> bool Triple.t Fold.t

    val length_in_triples : int
  end

  module Block : sig
    type 'a t_ = private 'a list

    type t = bool t_

    type var = Boolean.var t_

    val of_list_exn : 'a list -> 'a t_

    val list_to_padded_blocks : padding:'a -> 'a list -> 'a t_ list

    val length_in_bits : int

    val typ : (var, t) Typ.t
  end

  module State : sig
    type t

    type var

    val typ : (var, t) Typ.t

    val of_bits_exn : bool list -> t

    val default_init : t

    module Checked : sig
      val var_of_t : t -> var

      val of_bits_exn : Boolean.var list -> var

      val default_init : var

      val update : var -> Block.var -> (var, _) Checked.t

      val digest : var -> Digest.var
    end
  end
end = struct
  open Impl

  module Bits (M : sig
    val length_in_bits : int
  end) =
  struct
    include M

    type t = bool list [@@deriving sexp, bin_io, eq, compare]

    type var = Boolean.var list

    let fold xs = Fold.(group3 ~default:false (of_list xs))

    let typ = Typ.list ~length:length_in_bits Boolean.typ

    let length_in_triples = (M.length_in_bits + 2) / 3
  end

  module Digest = Bits (struct
    let length_in_bits = 256
  end)

  module Block = struct
    include Bits (struct
      let length_in_bits = 512
    end)

    type 'a t_ = 'a list

    let of_list_exn xs =
      assert (Int.equal (List.length xs) length_in_bits) ;
      xs

    let list_to_padded_blocks ~padding bits =
      let rec go blocks curr curr_length bs =
        match bs with
        | [] ->
            let padding_length = length_in_bits - curr_length in
            List.rev
              ( List.rev_append curr
                  (List.init padding_length ~f:(fun _ -> padding))
              :: blocks )
        | b :: bs ->
            if Int.equal curr_length length_in_bits then
              go (List.rev curr :: blocks) [b] 1 bs
            else go blocks (b :: curr) (curr_length + 1) bs
      in
      go [] [] 0 bits
  end

  module State = struct
    include Bits (struct
      let length_in_bits = 256
    end)

    let with_prefix = sprintf "%s_%s"

    let init_words =
      [| 0x6a09e667
       ; 0xbb67ae85
       ; 0x3c6ef372
       ; 0xa54ff53a
       ; 0x510e527f
       ; 0x9b05688c
       ; 0x1f83d9ab
       ; 0x5be0cd19 |]

    let of_bits_exn bits =
      assert (Int.equal (List.length bits) length_in_bits) ;
      bits

    let default_init =
      List.init length_in_bits ~f:(fun i ->
          (init_words.(i / 32) lsr (31 - (i mod 32))) land 1 = 1 )

    module Checked = struct
      let var_of_t = List.map ~f:Boolean.var_of_value

      let digest (x : var) : Digest.var = x

      let default_init = var_of_t default_init

      let of_bits_exn = of_bits_exn

      module Digest_variable = struct
        open Libsnark
        open Ctypes
        open Foreign

        type t = unit ptr

        let typ = ptr void

        let prefix = with_prefix Prefix.prefix "digest_variable"

        let func_name = with_prefix prefix

        let delete = foreign (func_name "delete") (typ @-> returning void)

        let create =
          let stub =
            foreign (func_name "create")
              (Protoboard.typ @-> int @-> returning typ)
          in
          fun pb n ->
            let t = stub pb n in
            Caml.Gc.finalise delete t ; t

        let bits =
          let stub =
            foreign (func_name "bits")
              (typ @-> returning Protoboard.Variable_array.typ)
          in
          fun t ->
            let bs = stub t in
            Caml.Gc.finalise Protoboard.Variable_array.delete bs ;
            bs

        (*
        (* This MUST be called to boolean constrain the output bits.
           The SHA256 gadget does not boolean constrain the output bits (see sha256_aux.tcc line 48)
        *)
        let generate_constraints =
          foreign (func_name "generate_r1cs_constraints") (typ @-> returning void) *)
      end

      module Compression_gadget = struct
        open Libsnark
        open Ctypes
        open Foreign

        type t = unit ptr

        let typ = ptr void

        let prefix =
          with_prefix Prefix.prefix "sha256_compression_function_gadget"

        let func_name = with_prefix prefix

        let delete = foreign (func_name "delete") (typ @-> returning void)

        let create =
          let stub =
            foreign (func_name "create")
              ( Protoboard.typ @-> Protoboard.Variable_array.typ
              @-> Protoboard.Variable_array.typ @-> Digest_variable.typ
              @-> returning typ )
          in
          fun pb prev_output new_block output ->
            let t = stub pb prev_output new_block output in
            Caml.Gc.finalise delete t ; t

        let generate_constraints =
          foreign
            (func_name "generate_r1cs_constraints")
            (typ @-> returning void)

        let generate_witness =
          foreign (func_name "generate_r1cs_witness") (typ @-> returning void)
      end

      module T = struct
        open Libsnark

        type input = {prev_state: var; block: Block.var}

        type witness = unit

        type t =
          { gadget: Compression_gadget.t
          ; output_unconstrained: Impl.Field.var list }

        let create pb conv conv_back {prev_state; block} =
          let conv_bits (bits : Boolean.var list) =
            let arr = Protoboard.Variable_array.create () in
            List.iter bits ~f:(fun b ->
                Protoboard.Variable_array.emplace_back arr
                  (conv (b :> Impl.Field.var)) ) ;
            arr
          in
          let prev_state = conv_bits prev_state in
          let block = conv_bits block in
          let output_var = Digest_variable.create pb Digest.length_in_bits in
          let gadget =
            Compression_gadget.create pb prev_state block output_var
          in
          let output_unconstrained =
            let bits = Digest_variable.bits output_var in
            List.init Digest.length_in_bits ~f:(fun i ->
                conv_back (Protoboard.Variable_array.get bits i) )
          in
          {gadget; output_unconstrained}

        let generate_constraints t =
          Compression_gadget.generate_constraints t.gadget

        let generate_witness t _input () =
          let open As_prover in
          map (return ()) ~f:(fun () ->
              Compression_gadget.generate_witness t.gadget )
      end

      module G = Gadget.Make (Impl) (Libsnark) (T)

      let update prev_state block =
        let open Let_syntax in
        let%bind gadget = G.create {prev_state; block} (As_prover.return ()) in
        Checked.List.map gadget.output_unconstrained ~f:Boolean.of_field
    end
  end
end
