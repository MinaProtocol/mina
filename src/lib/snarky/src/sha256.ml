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
    type t [@@deriving sexp, bin_io, compare, hash]

    include Comparable.S with type t := t

    type var = Boolean.var list

    val length_in_bits : int

    val typ : (var, t) Typ.t

    val fold_bits : t -> bool Fold.t

    val fold : t -> bool Triple.t Fold.t

    val length_in_triples : int

    val var_of_t : t -> var

    val to_bits : t -> bool list

    val to_string : t -> string

    val of_string : string -> t

    val of_bits : bool list -> t

    val var_to_triples : var -> Boolean.var Triple.t list
  end

  module Block : sig
    type t

    type var = Boolean.var list

    val of_list_exn : 'a list -> 'a list

    val list_to_padded_blocks : padding:'a -> 'a list -> 'a list list

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

    let bit_at s i = (Char.to_int s.[i / 8] lsr (7 - (i % 8))) land 1 = 1

    module T = struct
      type t = string [@@deriving sexp, bin_io, eq, compare, hash]
    end

    include T
    include Comparable.Make (T)

    type var = Boolean.var list

    let var_to_triples t =
      Fold.(to_list (group3 ~default:Boolean.false_ (of_list t)))

    let fold_bits s =
      { Fold.fold=
          (fun ~init ~f ->
            let n = 8 * String.length s in
            let rec go acc i =
              if Int.equal i n then acc
              else
                let b = bit_at s i in
                go (f acc b) (i + 1)
            in
            go init 0 ) }

    let fold t = Fold.group3 ~default:false (fold_bits t)

    let chunks_of n xs =
      List.groupi ~break:(fun i _ _ -> Int.equal (i mod n) 0) xs

    let bits_to_string bs =
      let bits_to_char_big_endian bs =
        List.foldi bs ~init:0 ~f:(fun i acc b ->
            if b then acc lor (1 lsl (7 - i)) else acc )
        |> Char.of_int_exn
      in
      chunks_of 8 bs
      |> List.map ~f:bits_to_char_big_endian
      |> String.of_char_list

    let to_bits s = List.init length_in_bits ~f:(fun i -> bit_at s i)

    let to_string = Fn.id

    let of_string = Fn.id

    let of_bits =
      let nearest_multiple ~of_:n k =
        let r = k mod n in
        if Int.equal r 0 then k else k - r + n
      in
      let pad zero bits =
        let n = List.length bits in
        let padding_length = nearest_multiple ~of_:length_in_bits n - n in
        bits @ List.init padding_length ~f:(fun _ -> zero)
      in
      Fn.compose bits_to_string (pad false)

    let typ =
      Typ.transport
        (Typ.list ~length:length_in_bits Boolean.typ)
        ~there:to_bits ~back:of_bits

    let length_in_triples = (M.length_in_bits + 2) / 3

    let var_of_t t = List.map (to_bits t) ~f:Boolean.var_of_value

    let gen = String.gen_with_length (length_in_bits / 8) Char.gen

    let%test_unit "to_bits compatible with fold" =
      Quickcheck.test gen ~f:(fun t ->
          [%test_eq: bool list] (Fold.to_list (fold_bits t)) (to_bits t) )

    let%test_unit "of_bits . to_bits = id" =
      Quickcheck.test gen ~f:(fun t -> assert (equal (of_bits (to_bits t)) t))

    let%test_unit "to_bits . of_bits = id" =
      Quickcheck.test (List.gen_with_length length_in_bits Bool.gen)
        ~f:(fun t -> [%test_eq: bool list] (to_bits (of_bits t)) t )
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
      of_bits bits

    let default_init =
      let init =
        List.init length_in_bits ~f:(fun i ->
            let open Int in
            (init_words.(i / 32) lsr (31 - (i mod 32))) land 1 = 1 )
      in
      bits_to_string init

    module Checked = struct
      let var_of_t = var_of_t

      let digest (x : var) : Digest.var = x

      let default_init = var_of_t default_init

      let of_bits_exn bits =
        assert (Int.equal (List.length bits) length_in_bits) ;
        bits

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
