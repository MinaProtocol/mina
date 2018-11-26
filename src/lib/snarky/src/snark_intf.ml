module Bignum_bigint = Bigint
open Core_kernel

module type Basic = sig
  module Proving_key : sig
    type t [@@deriving bin_io]

    val to_string : t -> string

    val of_string : string -> t

    val to_bigstring : t -> Bigstring.t

    val of_bigstring : Bigstring.t -> t
  end

  module Verification_key : sig
    type t [@@deriving bin_io]

    val to_string : t -> string

    val of_string : string -> t

    val to_bigstring : t -> Bigstring.t

    val of_bigstring : Bigstring.t -> t
  end

  module R1CS_constraint_system : sig
    type t

    val digest : t -> Md5.t
  end

  module Keypair : sig
    type t [@@deriving bin_io]

    val create : pk:Proving_key.t -> vk:Verification_key.t -> t

    val pk : t -> Proving_key.t

    val vk : t -> Verification_key.t

    val generate : R1CS_constraint_system.t -> t
  end

  module Var : sig
    include Comparable.S

    val create : int -> t
  end

  type field

  module Bigint : sig
    include Bigint_intf.Extended with type field := field

    val of_bignum_bigint : Bignum_bigint.t -> t

    val to_bignum_bigint : t -> Bignum_bigint.t
  end

  module rec Constraint : sig
    type t

    type 'k with_constraint_args = ?label:string -> 'k

    val boolean : (Field.Checked.t -> t) with_constraint_args

    val equal : (Field.Checked.t -> Field.Checked.t -> t) with_constraint_args

    val r1cs :
      (Field.Checked.t -> Field.Checked.t -> Field.Checked.t -> t)
      with_constraint_args

    val square : (Field.Checked.t -> Field.Checked.t -> t) with_constraint_args
  end
  
  and Data_spec : sig
    type ('r_var, 'r_value, 'k_var, 'k_value) t =
      | ( :: ) :
          ('var, 'value) Typ.t * ('r_var, 'r_value, 'k_var, 'k_value) t
          -> ('r_var, 'r_value, 'var -> 'k_var, 'value -> 'k_value) t
      | [] : ('r_var, 'r_value, 'r_var, 'r_value) t

    val size : (_, _, _, _) t -> int
  end
  
  and Typ : sig
    module Store : sig
      include Monad.S

      val store : field -> Field.Checked.t t
    end

    module Alloc : sig
      include Monad.S

      val alloc : Field.Checked.t t
    end

    module Read : sig
      include Monad.S

      val read : Field.Checked.t -> field t
    end

    type ('var, 'value) t =
      { store: 'value -> 'var Store.t
      ; read: 'var -> 'value Read.t
      ; alloc: 'var Alloc.t
      ; check: 'var -> (unit, unit) Checked.t }

    val store : ('var, 'value) t -> 'value -> 'var Store.t

    val read : ('var, 'value) t -> 'var -> 'value Read.t

    val alloc : ('var, 'value) t -> 'var Alloc.t

    val check : ('var, 'value) t -> 'var -> (unit, _) Checked.t

    val unit : (unit, unit) t

    val field : (Field.Checked.t, field) t

    val tuple2 :
         ('var1, 'value1) t
      -> ('var2, 'value2) t
      -> ('var1 * 'var2, 'value1 * 'value2) t

    val tuple3 :
         ('var1, 'value1) t
      -> ('var2, 'value2) t
      -> ('var3, 'value3) t
      -> ('var1 * 'var2 * 'var3, 'value1 * 'value2 * 'value3) t

    val hlist :
         (unit, unit, 'k_var, 'k_value) Data_spec.t
      -> ((unit, 'k_var) H_list.t, (unit, 'k_value) H_list.t) t

    val list : length:int -> ('var, 'value) t -> ('var list, 'value list) t

    val array : length:int -> ('var, 'value) t -> ('var array, 'value array) t

    (* synonym for tuple2 *)

    val ( * ) :
         ('var1, 'value1) t
      -> ('var2, 'value2) t
      -> ('var1 * 'var2, 'value1 * 'value2) t

    val transport :
         ('var, 'value1) t
      -> there:('value2 -> 'value1)
      -> back:('value1 -> 'value2)
      -> ('var, 'value2) t

    val transport_var :
         ('var1, 'value) t
      -> there:('var2 -> 'var1)
      -> back:('var1 -> 'var2)
      -> ('var2, 'value) t

    val of_hlistable :
         (unit, unit, 'k_var, 'k_value) Data_spec.t
      -> var_to_hlist:('var -> (unit, 'k_var) H_list.t)
      -> var_of_hlist:((unit, 'k_var) H_list.t -> 'var)
      -> value_to_hlist:('value -> (unit, 'k_value) H_list.t)
      -> value_of_hlist:((unit, 'k_value) H_list.t -> 'value)
      -> ('var, 'value) t

    module Of_traversable (T : Traversable.S) : sig
      val typ :
        template:unit T.t -> ('var, 'value) t -> ('var T.t, 'value T.t) t
    end
  end
  
  and Boolean : sig
    type var = private Field.Checked.t

    type value = bool

    val true_ : var

    val false_ : var

    val if_ : var -> then_:var -> else_:var -> (var, _) Checked.t

    val not : var -> var

    val ( && ) : var -> var -> (var, _) Checked.t

    val ( || ) : var -> var -> (var, _) Checked.t

    val any : var list -> (var, _) Checked.t

    val all : var list -> (var, _) Checked.t

    val of_field : Field.Checked.t -> (var, _) Checked.t

    val var_of_value : value -> var

    val typ : (var, value) Typ.t

    val typ_unchecked : (var, value) Typ.t

    val equal : var -> var -> (var, _) Checked.t

    module Expr : sig
      type t

      val ( ! ) : var -> t

      val ( && ) : t -> t -> t

      val ( || ) : t -> t -> t

      val any : t list -> t

      val all : t list -> t

      val not : t -> t

      val eval : t -> (var, _) Checked.t

      val assert_ : t -> (unit, _) Checked.t
    end

    module Unsafe : sig
      val of_cvar : Field.Checked.t -> var
    end

    module Assert : sig
      val ( = ) : Boolean.var -> Boolean.var -> (unit, _) Checked.t

      val is_true : Boolean.var -> (unit, _) Checked.t

      val any : var list -> (unit, _) Checked.t

      val all : var list -> (unit, _) Checked.t

      val exactly_one : var list -> (unit, _) Checked.t
    end
  end
  
  and Checked : sig
    include Monad.S2

    module List :
      Monad_sequence.S
      with type ('a, 's) monad := ('a, 's) t
       and type 'a t = 'a list
       and type boolean := Boolean.var

    type _ Request.t += Choose_preimage : field * int -> bool list Request.t
  end
  
  and Field : sig
    type t = field [@@deriving bin_io, sexp, hash, compare, eq]

    include Field_intf.Extended with type t := t

    include Stringable.S with type t := t

    val size : Bignum_bigint.t

    val unpack : t -> bool list

    val project : bool list -> t

    module Checked : sig
      type t

      val length : t -> int
      (** For debug purposes *)

      val var_indices : t -> int list

      val to_constant_and_terms : t -> field option * (field * Var.t) list

      val constant : field -> t

      val linear_combination : (field * t) list -> t

      val sum : t list -> t

      val add : t -> t -> t

      val sub : t -> t -> t

      val scale : t -> field -> t

      val mul : t -> t -> (t, _) Checked.t

      val square : t -> (t, _) Checked.t

      val div : t -> t -> (t, _) Checked.t

      val inv : t -> (t, _) Checked.t

      val equal : t -> t -> (Boolean.var, 's) Checked.t

      val project : Boolean.var list -> t

      val pack : Boolean.var list -> t

      val unpack : t -> length:int -> (Boolean.var list, _) Checked.t

      val unpack_flagged :
           t
        -> length:int
        -> (Boolean.var list * [`Success of Boolean.var], _) Checked.t

      val unpack_full :
        t -> (Boolean.var Bitstring_lib.Bitstring.Lsb_first.t, _) Checked.t

      val choose_preimage_var :
        t -> length:int -> (Boolean.var list, _) Checked.t

      type comparison_result = {less: Boolean.var; less_or_equal: Boolean.var}

      val compare :
        bit_length:int -> t -> t -> (comparison_result, _) Checked.t

      val if_ : Boolean.var -> then_:t -> else_:t -> (t, _) Checked.t

      module Infix : sig
        val ( + ) : t -> t -> t

        val ( - ) : t -> t -> t

        val ( * ) : field -> t -> t
      end

      module Unsafe : sig
        val of_var : Var.t -> t
      end

      module Assert : sig
        val lte : bit_length:int -> t -> t -> (unit, _) Checked.t

        val gte : bit_length:int -> t -> t -> (unit, _) Checked.t

        val lt : bit_length:int -> t -> t -> (unit, _) Checked.t

        val gt : bit_length:int -> t -> t -> (unit, _) Checked.t

        val not_equal : t -> t -> (unit, _) Checked.t

        val equal : t -> t -> (unit, _) Checked.t

        val non_zero : t -> (unit, _) Checked.t
      end
    end

    type var = Checked.t

    val typ : (var, t) Typ.t
  end

  include Monad.Syntax2 with type ('a, 's) t := ('a, 's) Checked.t

  module Proof : sig
    type t
  end

  module Bitstring_checked : sig
    type t = Boolean.var list

    val equal : t -> t -> (Boolean.var, _) Checked.t

    module Assert : sig
      val equal : t -> t -> (unit, _) Checked.t
    end
  end

  module As_prover : sig
    type ('a, 'prover_state) t

    type ('a, 'prover_state) as_prover = ('a, 'prover_state) t

    module Ref : sig
      type 'a t

      val create :
        ('a, 'prover_state) as_prover -> ('a t, 'prover_state) Checked.t

      val get : 'a t -> ('a, _) as_prover

      val set : 'a t -> 'a -> (unit, _) as_prover
    end

    include Monad.S2 with type ('a, 's) t := ('a, 's) t

    val map2 : ('a, 's) t -> ('b, 's) t -> f:('a -> 'b -> 'c) -> ('c, 's) t

    val read_var : Field.Checked.t -> (field, 'prover_state) t

    val get_state : ('prover_state, 'prover_state) t

    val set_state : 'prover_state -> (unit, 'prover_state) t

    val modify_state :
      ('prover_state -> 'prover_state) -> (unit, 'prover_state) t

    val read : ('var, 'value) Typ.t -> 'var -> ('value, 'prover_state) t
  end

  module Handle : sig
    type ('var, 'value) t = {var: 'var; value: 'value option}

    val value : (_, 'value) t -> ('value, _) As_prover.t

    val var : ('var, _) t -> 'var
  end

  val assert_ : ?label:string -> Constraint.t -> (unit, 's) Checked.t

  val assert_all : ?label:string -> Constraint.t list -> (unit, 's) Checked.t

  val assert_r1cs :
       ?label:string
    -> Field.Checked.t
    -> Field.Checked.t
    -> Field.Checked.t
    -> (unit, _) Checked.t

  val assert_square :
    ?label:string -> Field.Checked.t -> Field.Checked.t -> (unit, _) Checked.t

  val as_prover : (unit, 's) As_prover.t -> (unit, 's) Checked.t

  val with_state :
       ?and_then:('s1 -> (unit, 's) As_prover.t)
    -> ('s1, 's) As_prover.t
    -> ('a, 's1) Checked.t
    -> ('a, 's) Checked.t

  val next_auxiliary : (int, 's) Checked.t

  val request_witness :
       ('var, 'value) Typ.t
    -> ('value Request.t, 's) As_prover.t
    -> ('var, 's) Checked.t

  val perform : (unit Request.t, 's) As_prover.t -> (unit, 's) Checked.t

  val request :
       ?such_that:('var -> (unit, 's) Checked.t)
    -> ('var, 'value) Typ.t
    -> 'value Request.t
    -> ('var, 's) Checked.t
  (** TODO: Come up with a better name for this in relation to the above *)

  val provide_witness :
    ('var, 'value) Typ.t -> ('value, 's) As_prover.t -> ('var, 's) Checked.t

  val exists :
       ?request:('value Request.t, 's) As_prover.t
    -> ?compute:('value, 's) As_prover.t
    -> ('var, 'value) Typ.t
    -> ('var, 's) Checked.t

  type response = Request.response

  val unhandled : response

  type request = Request.request =
    | With :
        { request: 'a Request.t
        ; respond: 'a Request.Response.t -> response }
        -> request

  module Handler : sig
    type t = request -> response
  end

  val handle : ('a, 's) Checked.t -> Handler.t -> ('a, 's) Checked.t

  val with_label : string -> ('a, 's) Checked.t -> ('a, 's) Checked.t

  val with_constraint_system :
    (R1CS_constraint_system.t -> unit) -> (unit, _) Checked.t

  val constraint_system :
       exposing:((unit, 's) Checked.t, _, 'k_var, _) Data_spec.t
    -> 'k_var
    -> R1CS_constraint_system.t

  val generate_keypair :
       exposing:((unit, 's) Checked.t, _, 'k_var, _) Data_spec.t
    -> 'k_var
    -> Keypair.t

  val prove :
       Proving_key.t
    -> ((unit, 's) Checked.t, Proof.t, 'k_var, 'k_value) Data_spec.t
    -> 's
    -> 'k_var
    -> 'k_value

  val verify :
       Proof.t
    -> Verification_key.t
    -> (_, bool, _, 'k_value) Data_spec.t
    -> 'k_value

  val run_unchecked : ('a, 's) Checked.t -> 's -> 's * 'a

  val run_and_check :
    (('a, 's) As_prover.t, 's) Checked.t -> 's -> ('s * 'a) Or_error.t

  val check : ('a, 's) Checked.t -> 's -> bool

  val constraint_count : (_, _) Checked.t -> int
end

module type S = sig
  include Basic

  module Number :
    Number_intf.S
    with type ('a, 'b) checked := ('a, 'b) Checked.t
     and type field := field
     and type field_var := Field.Checked.t
     and type bool_var := Boolean.var

  module Enumerable (M : sig
    type t [@@deriving enum]
  end) :
    Enumerable_intf.S
    with type ('a, 'b) checked := ('a, 'b) Checked.t
     and type ('a, 'b) typ := ('a, 'b) Typ.t
     and type bool_var := Boolean.var
     and type var = Field.var
     and type t := M.t
end
