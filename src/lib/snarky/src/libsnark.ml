[%%import
"../../../config.mlh"]

open Core
open Ctypes
open Foreign

[%%if
call_logger]

let foreign name t =
  let f = foreign name t in
  fun x ->
    Coda_debug.Call_logger.record_call name ;
    f x

[%%endif]

let with_prefix prefix s = sprintf "%s_%s" prefix s

module type Foreign_intf = sig
  type t

  val typ : t Ctypes.typ
end

module type Deletable_intf = sig
  include Foreign_intf

  val delete : t -> unit
end

let set_profiling = foreign "camlsnark_set_profiling" (bool @-> returning void)

let () = set_profiling false

module Make_G1 (M : sig
  val prefix : string
end) (Field : sig
  type t

  val typ : t Ctypes.typ
end) (Bigint_r : sig
  type t

  val typ : t Ctypes.typ
end) (Fq : sig
  type t

  val typ : t Ctypes.typ

  val schedule_delete : t -> unit
end) =
struct
  module Group : sig
    type t

    val typ : t Ctypes.typ

    val add : t -> t -> t

    val negate : t -> t

    val double : t -> t

    val scale : t -> Bigint_r.t -> t

    val scale_field : t -> Field.t -> t

    val zero : t

    val one : t

    val to_coords : t -> Fq.t * Fq.t

    val of_coords : Fq.t * Fq.t -> t

    val equal : t -> t -> bool

    val random : unit -> t

    val delete : t -> unit

    val print : t -> unit

    module Vector : Vector.S with type elt := t
  end = struct
    type t = unit ptr

    let typ = ptr void

    let prefix = with_prefix M.prefix "g1"

    let func_name s = with_prefix prefix s

    let zero =
      let stub = foreign (func_name "zero") (void @-> returning typ) in
      stub ()

    let one =
      let stub = foreign (func_name "one") (void @-> returning typ) in
      stub ()

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let schedule_delete t = Caml.Gc.finalise delete t

    module Vector = Vector.Make (struct
      type elt = t

      let typ = typ

      let prefix = with_prefix prefix "vector"

      let schedule_delete = schedule_delete
    end)

    let print = foreign (func_name "print") (typ @-> returning void)

    let random =
      let stub = foreign (func_name "random") (void @-> returning typ) in
      fun () ->
        let x = stub () in
        schedule_delete x ; x

    let of_coords =
      let stub =
        foreign (func_name "of_coords") (Fq.typ @-> Fq.typ @-> returning typ)
      in
      fun (x, y) ->
        let t = stub x y in
        schedule_delete t ; t

    let double =
      let stub = foreign (func_name "double") (typ @-> returning typ) in
      fun x ->
        let z = stub x in
        schedule_delete z ; z

    let negate =
      let stub = foreign (func_name "negate") (typ @-> returning typ) in
      fun x ->
        let z = stub x in
        schedule_delete z ; z

    let add =
      let stub = foreign (func_name "add") (typ @-> typ @-> returning typ) in
      fun x y ->
        let z = stub x y in
        schedule_delete z ; z

    let scale =
      let stub =
        foreign (func_name "scale") (Bigint_r.typ @-> typ @-> returning typ)
      in
      fun y x ->
        let z = stub x y in
        schedule_delete z ; z

    let scale_field =
      let stub =
        foreign (func_name "scale_field") (Field.typ @-> typ @-> returning typ)
      in
      fun y x ->
        let z = stub x y in
        schedule_delete z ; z

    let equal = foreign (func_name "equal") (typ @-> typ @-> returning bool)

    let to_coords =
      let stub_to_affine =
        foreign (func_name "to_affine_coordinates") (typ @-> returning void)
      in
      let stub_x = foreign (func_name "x") (typ @-> returning Fq.typ) in
      let stub_y = foreign (func_name "y") (typ @-> returning Fq.typ) in
      fun t ->
        let () = stub_to_affine t in
        let x = stub_x t in
        Fq.schedule_delete x ;
        let y = stub_y t in
        Fq.schedule_delete y ; (x, y)
  end
end

module Make_common (M : sig
  val prefix : string
end) =
struct
  let prefix = M.prefix

  let init =
    foreign
      (with_prefix M.prefix "init_public_params")
      (void @-> returning void)

  let () = init ()

  module Field : sig
    type t [@@deriving sexp]

    val typ : t Ctypes.typ

    val add : t -> t -> t

    val sub : t -> t -> t

    val mul : t -> t -> t

    val inv : t -> t

    val is_square : t -> bool

    val sqrt : t -> t

    val square : t -> t

    val of_int : int -> t

    val one : t

    val zero : t

    val equal : t -> t -> bool

    val size_in_bits : int

    val random : unit -> t

    val delete : t -> unit

    val schedule_delete : t -> unit

    val print : t -> unit

    module Vector : Vector.S with type elt = t
  end = struct
    module T = struct
      type t = unit ptr sexp_opaque [@@deriving sexp]

      let typ = ptr void

      let prefix = with_prefix M.prefix "field"

      let func_name s = with_prefix prefix s

      let size_in_bits =
        let stub =
          foreign (func_name "size_in_bits") (void @-> returning int)
        in
        stub ()

      let delete = foreign (func_name "delete") (typ @-> returning void)

      let schedule_delete t = Caml.Gc.finalise delete t

      let print = foreign (func_name "print") (typ @-> returning void)

      let random =
        let stub = foreign (func_name "random") (void @-> returning typ) in
        fun () ->
          let x = stub () in
          schedule_delete x ; x

      let square =
        let stub = foreign (func_name "square") (typ @-> returning typ) in
        fun x ->
          let y = stub x in
          schedule_delete y ; y

      let is_square = foreign (func_name "is_square") (typ @-> returning bool)

      let sqrt =
        let stub = foreign (func_name "sqrt") (typ @-> returning typ) in
        fun x ->
          let y = stub x in
          schedule_delete y ; y

      let of_int =
        let stub = foreign (func_name "of_int") (int @-> returning typ) in
        fun n ->
          let x = stub n in
          schedule_delete x ; x

      let add =
        let stub = foreign (func_name "add") (typ @-> typ @-> returning typ) in
        fun x y ->
          let z = stub x y in
          schedule_delete z ; z

      let inv =
        let stub = foreign (func_name "inv") (typ @-> returning typ) in
        fun x ->
          let y = stub x in
          schedule_delete y ; y

      let mul =
        let stub = foreign (func_name "mul") (typ @-> typ @-> returning typ) in
        fun x y ->
          let z = stub x y in
          schedule_delete z ; z

      let sub =
        let stub = foreign (func_name "sub") (typ @-> typ @-> returning typ) in
        fun x y ->
          let z = stub x y in
          schedule_delete z ; z

      let equal = foreign (func_name "equal") (typ @-> typ @-> returning bool)

      let one = of_int 1

      let zero = of_int 0
    end

    module Vector = Vector.Make (struct
      type elt = T.t

      let typ = T.typ

      let prefix = with_prefix M.prefix "field_vector"

      let schedule_delete = Caml.Gc.finalise T.delete
    end)

    include T
  end

  module Var : sig
    type t

    val typ : t Ctypes.typ

    val index : t -> int

    val create : int -> t
  end = struct
    type t = unit ptr

    let func_name = with_prefix (with_prefix M.prefix "var")

    let typ = ptr void

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let create =
      (* TODO: Use size_t *)
      let stub = foreign (func_name "create") (int @-> returning typ) in
      fun n ->
        let v = stub n in
        Caml.Gc.finalise delete v ; v

    let index =
      let stub = foreign (func_name "index") (typ @-> returning size_t) in
      fun v ->
        let r = stub v in
        Unsigned.Size_t.to_int r
  end

  module Linear_combination : sig
    type t

    val typ : t Ctypes.typ

    val create : unit -> t

    val of_var : Var.t -> t

    val of_int : int -> t

    val of_field : Field.t -> t

    val print : t -> unit

    module Term : sig
      type t

      val create : Field.t -> Var.t -> t

      val coeff : t -> Field.t

      val var : t -> Var.t

      module Vector : Vector.S with type elt = t
    end

    val terms : t -> Term.Vector.t

    module Vector : Vector.S with type elt = t

    val add_term : t -> Field.t -> Var.t -> unit
  end = struct
    type t = unit ptr

    let typ = ptr void

    let prefix = with_prefix M.prefix "linear_combination"

    let func_name = with_prefix prefix

    module Term = struct
      type t = unit ptr

      let typ = ptr void

      let prefix = with_prefix prefix "term"

      let func_name = with_prefix prefix

      let delete = foreign (func_name "delete") (typ @-> returning void)

      let create =
        let stub =
          foreign (func_name "create") (Field.typ @-> Var.typ @-> returning typ)
        in
        fun x v ->
          let t = stub x v in
          Caml.Gc.finalise delete t ; t

      let coeff =
        let stub = foreign (func_name "coeff") (typ @-> returning Field.typ) in
        fun t ->
          let x = stub t in
          Caml.Gc.finalise Field.delete x ;
          x

      let var =
        let stub = foreign (func_name "index") (typ @-> returning int) in
        fun t -> Var.create (stub t)

      module Vector = Vector.Make (struct
        type elt = t

        let typ = typ

        let prefix = with_prefix prefix "vector"

        let schedule_delete = Caml.Gc.finalise delete
      end)
    end

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let schedule_delete t = Caml.Gc.finalise delete t

    module Vector = Vector.Make (struct
      type elt = t

      let typ = typ

      let prefix = with_prefix prefix "vector"

      let schedule_delete = schedule_delete
    end)

    let print = foreign (func_name "print") (typ @-> returning void)

    (*
    let substitute =
      foreign (func_name "substitute")
        (typ @-> Var.typ @-> Term.Vector.typ @-> returning void)
    ;; *)

    let create : unit -> t =
      let stub = foreign (func_name "create") (void @-> returning typ) in
      fun () ->
        let t = stub () in
        schedule_delete t ; t

    let of_var : Var.t -> t =
      let stub = foreign (func_name "of_var") (Var.typ @-> returning typ) in
      fun v ->
        let t = stub v in
        schedule_delete t ; t

    let of_int : int -> t =
      let stub = foreign (func_name "of_int") (int @-> returning typ) in
      fun n ->
        let t = stub n in
        schedule_delete t ; t

    let add_term =
      foreign (func_name "add_term")
        (typ @-> Field.typ @-> Var.typ @-> returning void)

    let terms =
      let stub =
        foreign (func_name "terms") (typ @-> returning Term.Vector.typ)
      in
      fun t ->
        let v = stub t in
        Caml.Gc.finalise Term.Vector.delete v ;
        v

    let of_field : Field.t -> t =
      let stub =
        foreign (func_name "of_field") (Field.typ @-> returning typ)
      in
      fun n ->
        let t = stub n in
        schedule_delete t ; t
  end

  module R1CS_constraint : sig
    type t

    val typ : t Ctypes.typ

    val create :
      Linear_combination.t -> Linear_combination.t -> Linear_combination.t -> t

    val set_is_square : t -> bool -> unit
  end = struct
    type t = unit ptr

    let typ = ptr void

    let prefix = with_prefix M.prefix "r1cs_constraint"

    let func_name = with_prefix prefix

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let create =
      let stub =
        foreign (func_name "create")
          ( Linear_combination.typ @-> Linear_combination.typ
          @-> Linear_combination.typ @-> returning typ )
      in
      fun a b c ->
        let t = stub a b c in
        Caml.Gc.finalise delete t ; t

    let set_is_square =
      foreign (func_name "set_is_square") (typ @-> bool @-> returning void)
  end

  module R1CS_constraint_system : sig
    type t

    val typ : t Ctypes.typ

    val create : unit -> t

    val delete : t -> unit

    val report_statistics : t -> unit

    val add_constraint : t -> R1CS_constraint.t -> unit

    val add_constraint_with_annotation :
      t -> R1CS_constraint.t -> string -> unit

    val set_primary_input_size : t -> int -> unit

    val set_auxiliary_input_size : t -> int -> unit

    val get_primary_input_size : t -> int

    val get_auxiliary_input_size : t -> int

    val check_exn : t -> unit

    val is_satisfied :
         t
      -> primary_input:Field.Vector.t
      -> auxiliary_input:Field.Vector.t
      -> bool

    val digest : t -> Md5.t
  end = struct
    type t = unit ptr

    let typ = ptr void

    let prefix = with_prefix M.prefix "r1cs_constraint_system"

    let func_name s = with_prefix prefix s

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let report_statistics =
      foreign (func_name "report_statistics") (typ @-> returning void)

    let check_exn =
      let stub = foreign (func_name "check") (typ @-> returning bool) in
      fun sys ->
        if not (stub sys) then failwith "R1CS_constraint_system.check_exn"

    let create =
      let stub = foreign (func_name "create") (void @-> returning typ) in
      fun () ->
        let t = stub () in
        Caml.Gc.finalise delete t ; t

    let add_constraint =
      foreign
        (func_name "add_constraint")
        (typ @-> R1CS_constraint.typ @-> returning void)

    let add_constraint_with_annotation =
      foreign
        (func_name "add_constraint_with_annotation")
        (typ @-> R1CS_constraint.typ @-> string @-> returning void)

    let set_primary_input_size =
      foreign
        (func_name "set_primary_input_size")
        (typ @-> int @-> returning void)

    let set_auxiliary_input_size =
      foreign
        (func_name "set_auxiliary_input_size")
        (typ @-> int @-> returning void)

    let get_primary_input_size =
      foreign (func_name "get_primary_input_size") (typ @-> returning int)

    let get_auxiliary_input_size =
      foreign (func_name "get_auxiliary_input_size") (typ @-> returning int)

    let is_satisfied =
      let stub =
        foreign (func_name "is_satisfied")
          ( typ @-> Field.Vector.typ @-> Field.Vector.typ
          @-> returning Ctypes.bool )
      in
      fun t ~primary_input ~auxiliary_input ->
        stub t primary_input auxiliary_input

    let digest =
      let stub =
        foreign (func_name "digest") (typ @-> returning Cpp_string.typ)
      in
      fun t ->
        let s = stub t in
        let r = Cpp_string.to_string s in
        Cpp_string.delete s ; Md5.of_binary_exn r
  end

  module Protoboard : sig
    type t

    val typ : t Ctypes.typ

    val create : unit -> t

    val auxiliary_input : t -> Field.Vector.t

    val num_variables : t -> int

    val set_input_sizes : t -> int -> unit

    val renumber_and_append_constraints :
         t
      -> R1CS_constraint_system.t
      -> Linear_combination.Vector.t
      -> int
      -> unit

    module Variable : sig
      type t

      val typ : t Ctypes.typ

      val delete : t -> unit

      val index : t -> int

      val of_int : int -> t
    end

    module Variable_array : sig
      type t

      val typ : t Ctypes.typ

      val emplace_back : t -> Variable.t -> unit

      val create : unit -> t

      val delete : t -> unit

      val get : t -> int -> Variable.t
    end

    val set_variable : t -> Variable.t -> Field.t -> unit

    val get_variable : t -> Variable.t -> Field.t

    val allocate_variable : t -> Variable.t

    val allocate_variable_array : t -> int -> Variable_array.t

    val augment_variable_annotation : t -> Variable.t -> string -> unit
  end = struct
    type t = unit ptr

    let typ = ptr void

    module Variable : sig
      type t

      val typ : t Ctypes.typ

      val delete : t -> unit

      val of_int : int -> t

      val index : t -> int
    end = struct
      type t = unit ptr

      let typ = ptr void

      let delete =
        foreign
          (with_prefix M.prefix "protoboard_variable_delete")
          (typ @-> returning void)

      let of_int =
        let stub =
          foreign
            (with_prefix M.prefix "protoboard_variable_of_int")
            (int @-> returning typ)
        in
        fun i ->
          let t = stub i in
          Caml.Gc.finalise delete t ; t

      let index =
        foreign
          (with_prefix M.prefix "protoboard_variable_index")
          (typ @-> returning int)
    end

    module Variable_array = struct
      type t = unit ptr

      let typ = ptr void

      let prefix = with_prefix M.prefix "protoboard_variable_array"

      let delete =
        foreign (with_prefix prefix "delete") (typ @-> returning void)

      let create =
        let stub =
          foreign (with_prefix prefix "create") (void @-> returning typ)
        in
        fun () ->
          let t = stub () in
          Caml.Gc.finalise delete t ; t

      let emplace_back =
        foreign
          (with_prefix prefix "emplace_back")
          (typ @-> Variable.typ @-> returning void)

      let get =
        let stub =
          foreign (with_prefix prefix "get")
            (typ @-> int @-> returning Variable.typ)
        in
        fun t i ->
          let v = stub t i in
          Caml.Gc.finalise Variable.delete v ;
          v
    end

    let func_name = with_prefix (with_prefix M.prefix "protoboard")

    let renumber_and_append_constraints =
      foreign
        (func_name "renumber_and_append_constraints")
        ( typ @-> R1CS_constraint_system.typ @-> Linear_combination.Vector.typ
        @-> int @-> returning void )

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let augment_variable_annotation =
      foreign
        (func_name "augment_variable_annotation")
        (typ @-> Variable.typ @-> string @-> returning void)

    let create =
      let stub = foreign (func_name "create") (void @-> returning typ) in
      fun () ->
        let t = stub () in
        Caml.Gc.finalise delete t ; t

    let num_variables =
      foreign (func_name "num_variables") (typ @-> returning int)

    let set_input_sizes =
      foreign (func_name "set_input_sizes") (typ @-> int @-> returning void)

    let set_variable =
      foreign (func_name "set_variable")
        (typ @-> Variable.typ @-> Field.typ @-> returning void)

    let get_variable =
      let stub =
        foreign (func_name "get_variable")
          (typ @-> Variable.typ @-> returning Field.typ)
      in
      fun t v ->
        let x = stub t v in
        Caml.Gc.finalise Field.delete x ;
        x

    let allocate_variable =
      let stub =
        foreign (func_name "allocate_variable") (typ @-> returning Variable.typ)
      in
      fun t ->
        let v = stub t in
        Caml.Gc.finalise Variable.delete v ;
        v

    let allocate_variable_array =
      let stub =
        foreign
          (func_name "allocate_variable_array")
          (typ @-> int @-> returning Variable_array.typ)
      in
      fun t n ->
        let v = stub t n in
        Caml.Gc.finalise Variable_array.delete v ;
        v

    let auxiliary_input =
      let stub =
        foreign
          (func_name "auxiliary_input")
          (typ @-> returning Field.Vector.typ)
      in
      fun t ->
        let v = stub t in
        Caml.Gc.finalise Field.Vector.delete v ;
        v
  end

  module Bigint : sig
    module R : sig
      type t [@@deriving bin_io]

      val typ : t Ctypes.typ

      val of_decimal_string : string -> t

      val of_numeral : string -> base:int -> t

      val of_field : Field.t -> t

      val div : t -> t -> t

      val to_field : t -> Field.t

      val compare : t -> t -> int

      val test_bit : t -> int -> bool

      val find_wnaf : Unsigned.Size_t.t -> t -> Long_vector.t
    end

    module Q : sig
      type t

      val typ : t Ctypes.typ

      val test_bit : t -> int -> bool

      val find_wnaf : Unsigned.Size_t.t -> t -> Long_vector.t
    end
  end = struct
    module Common (N : sig
      val prefix : string
    end) =
    struct
      type t = unit ptr

      let typ = ptr void

      let func_name =
        with_prefix (with_prefix (with_prefix M.prefix "bigint") N.prefix)

      let delete = foreign (func_name "delete") (typ @-> returning void)

      let test_bit =
        foreign (func_name "test_bit") (typ @-> int @-> returning bool)

      let find_wnaf =
        let stub =
          foreign (func_name "find_wnaf")
            (size_t @-> typ @-> returning Long_vector.typ)
        in
        fun x y ->
          let v = stub x y in
          Caml.Gc.finalise Long_vector.delete v ;
          v
    end

    module R = struct
      let prefix = "r"

      include Common (struct
        let prefix = prefix
      end)

      let func_name =
        with_prefix (with_prefix (with_prefix M.prefix "bigint") prefix)

      let div =
        let stub = foreign (func_name "div") (typ @-> typ @-> returning typ) in
        fun x y ->
          let z = stub x y in
          Caml.Gc.finalise delete z ; z

      let of_numeral =
        let stub =
          foreign (func_name "of_numeral")
            (string @-> int @-> int @-> returning typ)
        in
        fun s ~base ->
          let n = stub s (String.length s) base in
          Caml.Gc.finalise delete n ; n

      let of_decimal_string =
        let stub =
          foreign (func_name "of_decimal_string") (string @-> returning typ)
        in
        fun s ->
          let n = stub s in
          Caml.Gc.finalise delete n ; n

      let compare =
        foreign (func_name "compare") (typ @-> typ @-> returning int)

      let of_field =
        let stub =
          foreign (func_name "of_field") (Field.typ @-> returning typ)
        in
        fun x ->
          let n = stub x in
          Caml.Gc.finalise delete n ; n

      let num_limbs =
        let stub = foreign (func_name "num_limbs") (void @-> returning int) in
        stub ()

      let bytes_per_limb =
        let stub =
          foreign (func_name "bytes_per_limb") (void @-> returning int)
        in
        let res = stub () in
        assert (res = 8) ;
        res

      let length_in_bytes = num_limbs * bytes_per_limb

      let to_bigstring =
        let stub =
          foreign (func_name "to_data") (typ @-> returning (ptr char))
        in
        fun t ->
          let limbs = stub t in
          Bigstring.init length_in_bytes ~f:(fun i -> Ctypes.(!@(limbs +@ i)))

      let of_bigstring =
        let stub =
          foreign (func_name "of_data") (ptr char @-> returning typ)
        in
        fun s ->
          let ptr = Ctypes.bigarray_start Ctypes.array1 s in
          let t = stub ptr in
          Caml.Gc.finalise delete t ; t

      include Binable.Of_binable
                (Bigstring)
                (struct
                  type nonrec t = t

                  let to_binable = to_bigstring

                  let of_binable = of_bigstring
                end)

      let to_field =
        let stub =
          foreign (func_name "to_field") (typ @-> returning Field.typ)
        in
        fun n ->
          let x = stub n in
          Caml.Gc.finalise Field.delete x ;
          x
    end

    module Q = Common (struct
      let prefix = "q"
    end)
  end

  let field_size =
    let stub =
      foreign
        (with_prefix M.prefix "field_size")
        (void @-> returning Bigint.R.typ)
    in
    stub ()
end

module Make_proof_system (M : sig
  val prefix : string

  module R1CS_constraint_system : sig
    type t

    val typ : t Ctypes.typ
  end

  module Field : sig
    module Vector : sig
      type t

      val typ : t Ctypes.typ
    end
  end
end) =
struct
  module Proving_key : sig
    type t

    val typ : t Ctypes.typ

    val delete : t -> unit

    val to_string : t -> string

    val of_string : string -> t

    val to_bigstring : t -> Bigstring.t

    val of_bigstring : Bigstring.t -> t
  end = struct
    type t = unit ptr

    let typ = ptr void

    let prefix = with_prefix M.prefix "proving_key"

    let func_name = with_prefix prefix

    let delete = foreign (with_prefix prefix "delete") (typ @-> returning void)

    let to_string : t -> string =
      let stub =
        foreign (func_name "to_string") (typ @-> returning Cpp_string.typ)
      in
      fun t ->
        let s = stub t in
        let r = Cpp_string.to_string s in
        Cpp_string.delete s ; r

    let of_string : string -> t =
      let stub =
        foreign (func_name "of_string") (Cpp_string.typ @-> returning typ)
      in
      fun s ->
        let str = Cpp_string.of_string_don't_delete s in
        let t = stub str in
        Cpp_string.delete str ; t

    let to_bigstring : t -> Bigstring.t =
      let stub =
        foreign (func_name "to_string") (typ @-> returning Cpp_string.typ)
      in
      fun t ->
        let str = stub t in
        let length = Cpp_string.length str in
        let char_star = Cpp_string.to_char_pointer str in
        let bs =
          Ctypes.bigarray_of_ptr Ctypes.array1 length Bigarray.Char char_star
        in
        Caml.Gc.finalise (fun _ -> Cpp_string.delete str) bs ;
        bs

    let of_bigstring : Bigstring.t -> t =
      let stub =
        foreign (func_name "of_string") (Cpp_string.typ @-> returning typ)
      in
      fun bs ->
        let char_star = Ctypes.bigarray_start Ctypes.array1 bs in
        let str =
          Cpp_string.of_char_pointer_don't_delete char_star
            (Bigstring.length bs)
        in
        let t = stub str in
        Caml.Gc.finalise (fun _ -> delete t) t ;
        t
  end

  module Verification_key : sig
    type t

    val typ : t Ctypes.typ

    val delete : t -> unit

    val to_string : t -> string

    val of_string : string -> t

    val to_bigstring : t -> Bigstring.t

    val of_bigstring : Bigstring.t -> t

    val size_in_bits : t -> int
  end = struct
    type t = unit ptr

    let typ = ptr void

    let prefix = with_prefix M.prefix "verification_key"

    let func_name = with_prefix prefix

    let delete = foreign (with_prefix prefix "delete") (typ @-> returning void)

    let size_in_bits =
      foreign (func_name "size_in_bits") (typ @-> returning int)

    let to_string : t -> string =
      let stub =
        foreign (func_name "to_string") (typ @-> returning Cpp_string.typ)
      in
      fun t ->
        let s = stub t in
        let r = Cpp_string.to_string s in
        Cpp_string.delete s ; r

    let of_string : string -> t =
      let stub =
        foreign (func_name "of_string") (Cpp_string.typ @-> returning typ)
      in
      fun s ->
        let str = Cpp_string.of_string_don't_delete s in
        let t = stub str in
        Cpp_string.delete str ; t

    let to_bigstring : t -> Bigstring.t =
      let stub =
        foreign (func_name "to_string") (typ @-> returning Cpp_string.typ)
      in
      fun t ->
        let str = stub t in
        let length = Cpp_string.length str in
        let char_star = Cpp_string.to_char_pointer str in
        let bs =
          Ctypes.bigarray_of_ptr Ctypes.array1 length Bigarray.Char char_star
        in
        Caml.Gc.finalise (fun _ -> Cpp_string.delete str) bs ;
        bs

    let of_bigstring : Bigstring.t -> t =
      let stub =
        foreign (func_name "of_string") (Cpp_string.typ @-> returning typ)
      in
      fun bs ->
        let char_star = Ctypes.bigarray_start Ctypes.array1 bs in
        let str =
          Cpp_string.of_char_pointer_don't_delete char_star
            (Bigstring.length bs)
        in
        let t = stub str in
        Caml.Gc.finalise (fun _ -> delete t) t ;
        t
  end

  module Keypair : sig
    type t

    val typ : t Ctypes.typ

    val delete : t -> unit

    val pk : t -> Proving_key.t

    val vk : t -> Verification_key.t

    val create : M.R1CS_constraint_system.t -> t
  end = struct
    type t = unit ptr

    let typ = ptr void

    let prefix = with_prefix M.prefix "keypair"

    let func_name s = with_prefix prefix s

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let pk =
      let stub =
        foreign (func_name "pk") (typ @-> returning Proving_key.typ)
      in
      fun t ->
        let k = stub t in
        Caml.Gc.finalise Proving_key.delete k ;
        k

    let vk =
      let stub =
        foreign (func_name "vk") (typ @-> returning Verification_key.typ)
      in
      fun t ->
        let k = stub t in
        Caml.Gc.finalise Verification_key.delete k ;
        k

    let create =
      let stub =
        foreign (func_name "create")
          (M.R1CS_constraint_system.typ @-> returning typ)
      in
      fun sys ->
        let t = stub sys in
        Caml.Gc.finalise delete t ; t
  end

  module Proof : sig
    type t

    val typ : t Ctypes.typ

    val create :
         Proving_key.t
      -> primary:M.Field.Vector.t
      -> auxiliary:M.Field.Vector.t
      -> t

    val verify : t -> Verification_key.t -> M.Field.Vector.t -> bool

    val to_string : t -> string

    val of_string : string -> t
  end = struct
    type t = unit ptr

    let typ = ptr void

    let prefix = with_prefix M.prefix "proof"

    let func_name = with_prefix prefix

    let delete = foreign (func_name "delete") (typ @-> returning void)

    let to_string : t -> string =
      let stub =
        foreign (func_name "to_string") (typ @-> returning Cpp_string.typ)
      in
      fun t ->
        let s = stub t in
        let r = Cpp_string.to_string s in
        Cpp_string.delete s ; r

    let of_string : string -> t =
      let stub =
        foreign (func_name "of_string") (Cpp_string.typ @-> returning typ)
      in
      fun s ->
        let str = Cpp_string.of_string_don't_delete s in
        let t = stub str in
        Cpp_string.delete str ; t

    let create_ =
      let stub =
        foreign (func_name "create")
          ( Proving_key.typ @-> M.Field.Vector.typ @-> M.Field.Vector.typ
          @-> returning typ )
      in
      fun k primary auxiliary ->
        let t = stub k primary auxiliary in
        Caml.Gc.finalise delete t ; t

    let create key ~primary ~auxiliary = create_ key primary auxiliary

    let verify =
      foreign (func_name "verify")
        (typ @-> Verification_key.typ @-> M.Field.Vector.typ @-> returning bool)
  end
end

module Make_full (M : sig
  val prefix : string
end) =
struct
  module Common = Make_common (struct
    let prefix = M.prefix
  end)

  module Prefix = M

  module type Common_intf = module type of Common

  module Default = struct
    include Common
    include Make_proof_system (Common)
  end

  module GM = struct
    include Common

    include Make_proof_system (struct
      include Common

      let prefix = with_prefix M.prefix "gm"
    end)
  end

  include Common
end

module Bn128 = Make_full (struct
  let prefix = "camlsnark_bn128"
end)

module Mnt4_0 = Make_full (struct
  let prefix = "camlsnark_mnt4"
end)

module Mnt6_0 = Make_full (struct
  let prefix = "camlsnark_mnt6"
end)

module Make_GM_verification_key_accessors (Prefix : sig
  val prefix : string
end)
(Gm_verification_key : Foreign_intf) (G1 : sig
    include Deletable_intf

    module Vector : Deletable_intf
end)
(G2 : Deletable_intf) =
struct
  open Prefix

  let prefix = with_prefix prefix "gm_verification_key"

  let func_name = with_prefix prefix

  let func name ret delete =
    let stub =
      foreign (func_name name) (Gm_verification_key.typ @-> returning ret)
    in
    fun vk ->
      let r = stub vk in
      Caml.Gc.finalise delete r ; r

  let h = func "h" G2.typ G2.delete

  let g_alpha = func "g_alpha" G1.typ G1.delete

  let h_beta = func "h_beta" G2.typ G2.delete

  let g_gamma = func "g_gamma" G1.typ G1.delete

  let h_gamma = func "h_gamma" G2.typ G2.delete

  let query = func "query" G1.Vector.typ G1.Vector.delete
end

module Make_GM_proof_accessors (Prefix : sig
  val prefix : string
end)
(Proof : Foreign_intf) (G1 : sig
    include Deletable_intf

    module Vector : Deletable_intf
end)
(G2 : Deletable_intf) =
struct
  open Prefix

  let prefix = with_prefix prefix "gm_proof"

  let func_name = with_prefix prefix

  let func name ret delete =
    let stub = foreign (func_name name) (Proof.typ @-> returning ret) in
    fun vk ->
      let r = stub vk in
      Caml.Gc.finalise delete r ; r

  let a = func "a" G1.typ G1.delete

  let b = func "b" G2.typ G2.delete

  let c = func "c" G1.typ G1.delete
end

(* TODO: Clean this up and unify with G1 *)
module Make_G2 (Prefix : sig
  val prefix : string
end) (Fq : sig
  include Deletable_intf

  module Vector : Deletable_intf
end) =
struct
  type t = unit ptr

  let typ = ptr void

  let prefix = with_prefix Prefix.prefix "g2"

  let func_name = with_prefix prefix

  let delete = foreign (func_name "delete") (typ @-> returning void)

  let to_coords =
    let coord name =
      let stub = foreign (func_name name) (typ @-> returning Fq.Vector.typ) in
      fun t ->
        let r = stub t in
        Caml.Gc.finalise Fq.Vector.delete r ;
        r
    in
    let to_affine =
      foreign (func_name "to_affine_coordinates") (typ @-> returning void)
    in
    let get_x = coord "x" in
    let get_y = coord "y" in
    fun t ->
      to_affine t ;
      (get_x t, get_y t)
end

module Mnt4 = struct
  include Mnt4_0
  module G2 = Make_G2 (Prefix) (Mnt6_0.Field)
  include Make_G1 (Prefix) (Mnt4_0.Field) (Mnt4_0.Bigint.R) (Mnt6_0.Field)
  module GM_proof_accessors =
    Make_GM_proof_accessors (Prefix) (GM.Proof) (Group) (G2)
  module GM_verification_key_accessors =
    Make_GM_verification_key_accessors (Prefix) (GM.Verification_key) (Group)
      (G2)
end

module Mnt6 = struct
  include Mnt6_0
  module G2 = Make_G2 (Prefix) (Mnt4_0.Field)
  include Make_G1 (Prefix) (Mnt6_0.Field) (Mnt6_0.Bigint.R) (Mnt4_0.Field)
  module GM_proof_accessors =
    Make_GM_proof_accessors (Prefix) (GM.Proof) (Group) (G2)
  module GM_verification_key_accessors =
    Make_GM_verification_key_accessors (Prefix) (GM.Verification_key) (Group)
      (G2)
end

module type S = sig
  val prefix : string

  val init : unit -> unit

  module Field : sig
    type t

    val typ : t Ctypes.typ

    val add : t -> t -> t

    val sub : t -> t -> t

    val mul : t -> t -> t

    val inv : t -> t

    val is_square : t -> bool

    val sqrt : t -> t

    val square : t -> t

    val of_int : int -> t

    val one : t

    val zero : t

    val equal : t -> t -> bool

    val size_in_bits : int

    val random : unit -> t

    val delete : t -> unit

    val print : t -> unit

    module Vector : sig
      type elt = t

      type t

      val typ : t Ctypes.typ

      val delete : t -> unit

      val create : unit -> t

      val get : t -> int -> elt

      val emplace_back : t -> elt -> unit

      val length : t -> int
    end
  end

  module Var : sig
    type t

    val typ : t Ctypes.typ

    val index : t -> int

    val create : int -> t
  end

  module Linear_combination : sig
    type t

    val typ : t Ctypes.typ

    val create : unit -> t

    val of_var : Var.t -> t

    val of_int : int -> t

    val of_field : Field.t -> t

    val print : t -> unit

    module Term : sig
      type t

      val create : Field.t -> Var.t -> t

      val coeff : t -> Field.t

      val var : t -> Var.t

      module Vector : sig
        type elt = t

        type t

        val typ : t Ctypes.typ

        val delete : t -> unit

        val create : unit -> t

        val get : t -> int -> elt

        val emplace_back : t -> elt -> unit

        val length : t -> int
      end
    end

    val terms : t -> Term.Vector.t

    module Vector : sig
      type elt = t

      type t

      val typ : t Ctypes.typ

      val delete : t -> unit

      val create : unit -> t

      val get : t -> int -> elt

      val emplace_back : t -> elt -> unit

      val length : t -> int
    end

    val add_term : t -> Field.t -> Var.t -> unit
  end

  module R1CS_constraint : sig
    type t

    val typ : t Ctypes.typ

    val create :
      Linear_combination.t -> Linear_combination.t -> Linear_combination.t -> t
  end

  module R1CS_constraint_system : sig
    type t

    val typ : t Ctypes.typ

    val create : unit -> t

    val delete : t -> unit

    val report_statistics : t -> unit

    val add_constraint : t -> R1CS_constraint.t -> unit

    val add_constraint_with_annotation :
      t -> R1CS_constraint.t -> string -> unit

    val set_primary_input_size : t -> int -> unit

    val set_auxiliary_input_size : t -> int -> unit

    val get_primary_input_size : t -> int

    val get_auxiliary_input_size : t -> int

    val check_exn : t -> unit

    val is_satisfied :
         t
      -> primary_input:Field.Vector.t
      -> auxiliary_input:Field.Vector.t
      -> bool

    val digest : t -> Core.Md5.t
  end

  module Protoboard : sig
    type t

    val typ : t Ctypes.typ

    val create : unit -> t

    val auxiliary_input : t -> Field.Vector.t

    val num_variables : t -> int

    val set_input_sizes : t -> int -> unit

    val renumber_and_append_constraints :
         t
      -> R1CS_constraint_system.t
      -> Linear_combination.Vector.t
      -> int
      -> unit

    module Variable : sig
      type t

      val typ : t Ctypes.typ

      val delete : t -> unit

      val index : t -> int

      val of_int : int -> t
    end

    module Variable_array : sig
      type t

      val typ : t Ctypes.typ

      val emplace_back : t -> Variable.t -> unit

      val create : unit -> t

      val delete : t -> unit

      val get : t -> int -> Variable.t
    end

    val set_variable : t -> Variable.t -> Field.t -> unit

    val get_variable : t -> Variable.t -> Field.t

    val allocate_variable : t -> Variable.t

    val allocate_variable_array : t -> int -> Variable_array.t

    val augment_variable_annotation : t -> Variable.t -> string -> unit
  end

  module Bigint : sig
    module R : sig
      type t

      val typ : t Ctypes.typ

      val of_decimal_string : string -> t

      val of_numeral : string -> base:int -> t

      val of_field : Field.t -> t

      val div : t -> t -> t

      val to_field : t -> Field.t

      val compare : t -> t -> int

      val test_bit : t -> int -> bool

      val find_wnaf : Unsigned.Size_t.t -> t -> Long_vector.t
    end

    module Q : sig
      type t

      val typ : t Ctypes.typ

      val test_bit : t -> int -> bool

      val find_wnaf : Unsigned.Size_t.t -> t -> Long_vector.t
    end
  end

  val field_size : Bigint.R.t

  module Proving_key : sig
    type t

    val typ : t Ctypes.typ

    val delete : t -> unit

    val to_string : t -> string

    val of_string : string -> t

    val to_bigstring : t -> Core.Bigstring.t

    val of_bigstring : Core.Bigstring.t -> t
  end

  module Verification_key : sig
    type t

    val typ : t Ctypes.typ

    val delete : t -> unit

    val to_string : t -> string

    val of_string : string -> t

    val to_bigstring : t -> Core.Bigstring.t

    val of_bigstring : Core.Bigstring.t -> t

    val size_in_bits : t -> int
  end

  module Keypair : sig
    type t

    val typ : t Ctypes.typ

    val delete : t -> unit

    val pk : t -> Proving_key.t

    val vk : t -> Verification_key.t

    val create : R1CS_constraint_system.t -> t
  end

  module Proof : sig
    type t

    val typ : t Ctypes.typ

    val create :
      Proving_key.t -> primary:Field.Vector.t -> auxiliary:Field.Vector.t -> t

    val verify : t -> Verification_key.t -> Field.Vector.t -> bool

    val to_string : t -> string

    val of_string : string -> t
  end
end

module Curves = struct
  let mk_coeff typ name =
    let stub = foreign name (void @-> returning typ) in
    stub ()

  let mk_generator typ delete curve_name =
    let prefix = sprintf "camlsnark_%s_generator" curve_name in
    let mk s =
      let stub = foreign (with_prefix prefix s) (void @-> returning typ) in
      let r = stub () in
      Caml.Gc.finalise delete r ; r
    in
    (mk "x", mk "y")

  module Make_coefficients (Base_field : sig
    type t

    val typ : t Ctypes.typ
  end) (M : sig
    val curve_name : string
  end) =
  struct
    let prefix = sprintf "camlsnark_%s_coeff" M.curve_name

    let a = mk_coeff Base_field.typ (with_prefix prefix "a")

    let b = mk_coeff Base_field.typ (with_prefix prefix "b")
  end

  module Mnt4 = struct
    module G1 = struct
      let generator = mk_generator Mnt6.Field.typ Mnt6.Field.delete "mnt4_G1"

      module Coefficients =
        Make_coefficients
          (Mnt6.Field)
          (struct
            let curve_name = "mnt4_G1"
          end)
    end
  end

  module Mnt6 = struct
    module G1 = struct
      let generator =
        mk_generator Mnt4_0.Field.typ Mnt4_0.Field.delete "mnt6_G1"

      module Coefficients =
        Make_coefficients
          (Mnt4_0.Field)
          (struct
            let curve_name = "mnt6_G1"
          end)
    end

    let final_exponent_last_chunk_abs_of_w0 =
      !@(foreign_value "camlsnark_mnt6_final_exponent_last_chunk_abs_of_w0"
           Mnt6.Bigint.Q.typ)

    let final_exponent_last_chunk_w1 =
      !@(foreign_value "camlsnark_mnt6_final_exponent_last_chunk_w1"
           Mnt6.Bigint.Q.typ)
  end
end
