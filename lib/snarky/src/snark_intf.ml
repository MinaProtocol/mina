open Core_kernel

module type Basic = sig
  module R1CS_constraint_system : sig
    type t
  end

  module Var : sig
    include Comparable.S
    val create : int -> t
  end

  type field

  module Bigint : sig
    include Bigint_intf.Extended with type field := field
    val of_bignum_bigint : Bignum.Bigint.t -> t
    val to_bignum_bigint : t -> Bignum.Bigint.t
  end

  module Cvar : sig
    type t

    (* For debug purposes *)
    val length : t -> int
    val var_indices : t -> int list
    val to_constant_and_terms : t -> field option * (field * Var.t) list

    val constant : field -> t

    val linear_combination : (field * t) list -> t
    val sum : t list -> t
    val add : t -> t -> t
    val sub : t -> t -> t
    val scale : t -> field -> t

    module Infix : sig
      val (+) : t -> t -> t
      val (-) : t -> t -> t
      val ( * ) : field -> t -> t
    end

    module Unsafe : sig
      val of_var : Var.t -> t
    end
  end

  module Constraint : sig
    type t

    type 'k with_constraint_args = ?label:string -> 'k

    val boolean : (Cvar.t -> t) with_constraint_args
    val equal : (Cvar.t -> Cvar.t -> t) with_constraint_args
    val r1cs
      : (Cvar.t -> Cvar.t -> Cvar.t -> t) with_constraint_args
  end

  module rec Data_spec : sig
    type ('r_var, 'r_value, 'k_var, 'k_value) t =
      | (::)
        : ('var, 'value) Typ.t
          * ('r_var, 'r_value, 'k_var, 'k_value) t
        -> ('r_var, 'r_value, 'var -> 'k_var, 'value -> 'k_value) t
      | [] : ('r_var, 'r_value, 'r_var, 'r_value) t

    val size : (_, _, _, _) t -> int
  end
  and Typ : sig
    module Store : sig
      include Monad.S

      val store : field -> Cvar.t t
    end

    module Alloc : sig
      include Monad.S

      val alloc : Cvar.t t
    end

    module Read : sig
      include Monad.S

      val read : Cvar.t -> field t
    end

    type ('var, 'value) t =
      { store : 'value -> 'var Store.t
      ; read : 'var -> 'value Read.t
      ; alloc : 'var Alloc.t
      ; check : 'var -> (unit, unit) Checked.t
      }

    val store : ('var, 'value) t -> 'value -> 'var Store.t
    val read  : ('var, 'value) t -> 'var -> 'value Read.t
    val alloc : ('var, 'value) t -> 'var Alloc.t
    val check : ('var, 'value) t -> 'var -> (unit, _) Checked.t

    val unit : (unit, unit) t
    val field  : (Cvar.t, field) t
    val tuple2 : ('var1, 'value1) t -> ('var2, 'value2) t -> ('var1 * 'var2, 'value1 * 'value2) t
    val tuple3
      : ('var1, 'value1) t -> ('var2, 'value2) t -> ('var3, 'value3) t
      -> ('var1 * 'var2 * 'var3, 'value1 * 'value2 * 'value3) t
    val hlist
      : (unit, unit, 'k_var, 'k_value) Data_spec.t
      -> ((unit, 'k_var) H_list.t, (unit, 'k_value) H_list.t) t
    val list  : length:int -> ('var, 'value) t -> ('var list, 'value list) t
    val array : length:int -> ('var, 'value) t -> ('var array, 'value array) t
 
    (* synonym for tuple2 *)
    val ( * ) : ('var1, 'value1) t -> ('var2, 'value2) t -> ('var1 * 'var2, 'value1 * 'value2) t

    val transport
      : ('var, 'value1) t
      -> there:('value2 -> 'value1)
      -> back:('value1 -> 'value2)
      -> ('var, 'value2) t

    val of_hlistable
      : (unit, unit, 'k_var, 'k_value) Data_spec.t
      -> var_to_hlist : ('var -> (unit, 'k_var) H_list.t)
      -> var_of_hlist : ((unit, 'k_var) H_list.t -> 'var)
      -> value_to_hlist : ('value -> (unit, 'k_value) H_list.t)
      -> value_of_hlist : ((unit, 'k_value) H_list.t -> 'value)
      -> ('var, 'value) t

    module Of_traversable (T : Traversable.S) : sig
      val typ : template:unit T.t -> ('var, 'value) t -> ('var T.t, 'value T.t) t
    end
  end
  and Boolean : sig
    type var = private Cvar.t
    type value = bool

    val true_ : var
    val false_ : var

    val not : var -> var

    val (&&) : var -> var -> (var, _) Checked.t

    val (||) : var -> var -> (var, _) Checked.t

    val any : var list -> (var, _) Checked.t

    val all : var list -> (var, _) Checked.t

    val var_of_value : value -> var

    val typ : (var, value) Typ.t
    val typ_unchecked : (var, value) Typ.t

    module Expr : sig
      type t

      val (!) : var -> t
      val (&&) : t -> t -> t
      val (||) : t -> t -> t
      val any : t list -> t
      val all : t list -> t
      val not : t -> t

      val eval : t -> (var, _) Checked.t
      val assert_ : t -> (unit, _) Checked.t
    end

    module Unsafe : sig
      val of_cvar : Cvar.t -> var
    end

    module Assert : sig
      val (=) : Boolean.var -> Boolean.var -> (unit, _) Checked.t

      val is_true : Boolean.var -> (unit, _) Checked.t

      val any : var list -> (unit, _) Checked.t

      val all : var list -> (unit, _) Checked.t

      val exactly_one : var list -> (unit, _) Checked.t
    end
  end
  and
  Checked : sig
    include Monad.S2

    module List : Monad_sequence.S
      with type ('a, 's) monad := ('a, 's) t
       and type 'a t = 'a list
       and type boolean := Boolean.var

    val mul : Cvar.t -> Cvar.t -> (Cvar.t, _) t
    val div : Cvar.t -> Cvar.t -> (Cvar.t, _) t

    val inv : Cvar.t -> (Cvar.t, _) t

    val if_ : Boolean.var -> then_:Cvar.t -> else_:Cvar.t -> (Cvar.t, _) t

    val equal
      : Cvar.t
      -> Cvar.t
      -> (Boolean.var, 's) t

    val project : Boolean.var list -> Cvar.t
    val pack : Boolean.var list -> Cvar.t

    type _ Request.t +=
      | Choose_preimage : field * int -> bool list Request.t
    val choose_preimage
      : Cvar.t -> length:int -> (Boolean.var list, _) t

    val unpack : Cvar.t -> length:int -> (Boolean.var list, _) t

    type comparison_result =
      { less : Boolean.var
      ; less_or_equal : Boolean.var
      }

    val compare : bit_length:int -> Cvar.t -> Cvar.t -> (comparison_result, _) t

    val equal_bitstrings
      : Boolean.var list -> Boolean.var list -> (Boolean.var, _) t

    module Assert : sig
      val lte : bit_length:int -> Cvar.t -> Cvar.t -> (unit, _) t
      val gte : bit_length:int -> Cvar.t -> Cvar.t -> (unit, _) t
      val lt : bit_length:int -> Cvar.t -> Cvar.t -> (unit, _) t
      val gt : bit_length:int -> Cvar.t -> Cvar.t -> (unit, _) t

      val equal_bitstrings
        : Boolean.var list
        -> Boolean.var list
        -> (unit, _) t

      val not_equal : Cvar.t -> Cvar.t -> (unit, _) t

      val non_zero : Cvar.t -> (unit, _) t
    end
  end

  module Field : sig
    include Field_intf.Extended with type t = field
    include Sexpable.S with type t := t

    type var = Cvar.t

    val typ : (var, t) Typ.t

    val size : Bignum.Bigint.t
    val unpack : t -> bool list
    val project : bool list -> t
  end

  include Monad.Syntax2 with type ('a, 's) t := ('a, 's) Checked.t

  module Proving_key : sig
    type t
    val to_string : t -> string
    val of_string : string -> t
    val to_bigstring : t -> Bigstring.t
    val of_bigstring : Bigstring.t -> t
  end

  module Verification_key : sig
    type t
    val to_string : t -> string
    val of_string : string -> t
    val to_bigstring : t -> Bigstring.t
    val of_bigstring : Bigstring.t -> t
  end

  module Keypair : sig
    type t
    val pk : t -> Proving_key.t
    val vk : t -> Verification_key.t
  end

  module Proof : sig
    type t
  end

  module As_prover : sig
    type ('a, 'prover_state) t
    type ('a, 'prover_state) as_prover = ('a, 'prover_state) t

    module Ref : sig
      type 'a t

      val create
        : ('a, 'prover_state) as_prover
        -> ('a t, 'prover_state) Checked.t

      val get : 'a t -> ('a, _) as_prover
      val set : 'a t -> 'a -> (unit, _) as_prover
    end

    include Monad.S2 with type ('a, 's) t := ('a, 's) t

    val map2 : ('a, 's) t -> ('b, 's) t -> f:('a -> 'b -> 'c) -> ('c, 's) t

    val read_var  : Cvar.t -> (field, 'prover_state) t
    val get_state : ('prover_state, 'prover_state) t
    val set_state : 'prover_state -> (unit, 'prover_state) t
    val modify_state : ('prover_state -> 'prover_state) -> (unit, 'prover_state) t
    val read
      : ('var, 'value) Typ.t
      -> 'var
      -> ('value, 'prover_state) t
  end

  module Handle : sig
    type ('var, 'value) t = { var : 'var; value: 'value option }

    val value : (_, 'value) t -> ('value, _) As_prover.t
    val var : ('var, _) t -> 'var
  end

  val assert_ : ?label:string -> Constraint.t -> (unit, 's) Checked.t
  val assert_all : ?label:string -> Constraint.t list -> (unit, 's) Checked.t
  val assert_r1cs
    : ?label:string ->
    Cvar.t
    -> Cvar.t
    -> Cvar.t
    -> (unit, _) Checked.t
  val assert_equal
    : ?label:string -> Cvar.t -> Cvar.t -> (unit, 's) Checked.t

  val as_prover : (unit, 's) As_prover.t -> (unit, 's) Checked.t

  val with_state
    : ?and_then:('s1 -> (unit, 's) As_prover.t)
    -> ('s1, 's) As_prover.t
    -> ('a, 's1) Checked.t
    -> ('a, 's) Checked.t

  val next_auxiliary : (int, 's) Checked.t

  val request_witness
    : ('var, 'value) Typ.t
    -> ('value Request.t, 's) As_prover.t
    -> ('var, 's) Checked.t

  val perform : (unit Request.t, 's) As_prover.t -> (unit, 's) Checked.t

  (* TODO: Come up with a better name for this in relation to the above *)
  val request
    : ?such_that:('var -> (unit, 's) Checked.t)
    -> ('var, 'value) Typ.t
    -> 'value Request.t
    -> ('var, 's) Checked.t

  val provide_witness
    : ('var, 'value) Typ.t
    -> ('value, 's) As_prover.t
    -> ('var, 's) Checked.t

  val exists
    : ?request:('value Request.t, 's) As_prover.t
    -> ?compute:('value, 's) As_prover.t
    -> ('var, 'value) Typ.t
    -> ('var, 's) Checked.t

  type response = Request.response
  val unhandled : response
  type request
    = Request.request
    = With : { request :'a Request.t; respond : ('a Request.Response.t -> response) } -> request

  module Handler : sig
    type t = request -> response
  end

  val handle : ('a, 's) Checked.t -> Handler.t -> ('a, 's) Checked.t

  val with_label : string -> ('a, 's) Checked.t -> ('a, 's) Checked.t

  val with_constraint_system
    : (R1CS_constraint_system.t -> unit) -> (unit, _) Checked.t

  val generate_keypair
    : exposing:((unit, 's) Checked.t, _, 'k_var, _) Data_spec.t
    -> 'k_var
    -> Keypair.t

  val prove
    : Proving_key.t
    -> ((unit, 's) Checked.t, Proof.t, 'k_var, 'k_value) Data_spec.t
    -> 's
    -> 'k_var
    -> 'k_value

  val verify
    : Proof.t
    -> Verification_key.t
    -> (_, bool, _, 'k_value) Data_spec.t
    -> 'k_value

  val run_unchecked : ('a, 's) Checked.t -> 's -> 's * 'a

  val run_and_check
    : (('a, 's) As_prover.t, 's) Checked.t -> 's -> ('s * 'a) Or_error.t

  val check : ('a, 's) Checked.t -> 's -> bool
end

module type S = sig
  include Basic
  module Number : Number_intf.S
    with type ('a, 'b) checked := ('a, 'b) Checked.t
     and type field := field
     and type field_var := Cvar.t
     and type bool_var := Boolean.var

  module Enumerable
    : functor (M : sig type t [@@deriving enum] end) ->
      Enumerable_intf.S
      with type ('a, 'b) checked := ('a, 'b) Checked.t
       and type ('a, 'b) typ := ('a, 'b) Typ.t
       and type bool_var := Boolean.var
       and type var = Field.var
       and type t := M.t
end

