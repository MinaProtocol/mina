module type S = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  module Stable : sig
    module V1 : sig
      type nonrec t = t

      val to_yojson : t -> Yojson.Safe.t

      val bin_size_t : t Bin_prot.Size.sizer

      val bin_write_t : t Bin_prot.Write.writer

      val bin_read_t : t Bin_prot.Read.reader

      val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

      val bin_shape_t : Bin_prot.Shape.t

      val bin_writer_t : t Bin_prot.Type_class.writer

      val bin_reader_t : t Bin_prot.Type_class.reader

      val bin_t : t Bin_prot.Type_class.t

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      val __versioned__ : unit
    end

    module Latest = V1
  end

  module Coinbase_data : sig
    module Stable : sig
      module V1 : sig
        type t =
          Signature_lib.Public_key.Compressed.Stable.V1.t
          * Currency.Amount.Stable.V1.t

        val to_yojson : t -> Yojson.Safe.t

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t
      end

      module Latest = V1
    end

    type t = Stable.V1.t

    val to_yojson : t -> Yojson.Safe.t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    type var = Signature_lib.Public_key.Compressed.var * Currency.Amount.var

    val typ : (var, t) Snark_params.Tick.Typ.t

    val empty : t

    val of_coinbase : Coinbase.t -> t

    val genesis : t

    val var_of_t : t -> var
  end

  module type Data_hash_intf = sig
    type t = private Snark_params.Tick.Field.t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    val compare : t -> t -> int

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    type var

    val var_of_t : t -> var

    val typ : (var, t) Snark_params.Tick.Typ.t

    val var_to_hash_packed : var -> Snark_params.Tick.Field.Var.t

    val equal_var :
         var
      -> var
      -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

    val to_bytes : t -> string

    val to_bits : t -> bool list

    val gen : t Core.Quickcheck.Generator.t
  end

  module rec Hash : sig
    type t = private Snark_params.Tick.Field.t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    val compare : t -> t -> int

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    type var

    val var_of_t : t -> var

    val typ : (var, t) Snark_params.Tick.Typ.t

    val var_to_hash_packed : var -> Snark_params.Tick.Field.Var.t

    val equal_var :
         var
      -> var
      -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

    val to_bytes : t -> string

    val to_bits : t -> bool list

    val gen : t Core.Quickcheck.Generator.t

    val merge : height:int -> t -> t -> t

    val empty_hash : t

    val of_digest : Random_oracle.Digest.t -> t
  end

  module Hash_versioned : sig
    module Stable : sig
      module V1 : sig
        type nonrec t = Hash.t

        val to_yojson : t -> Yojson.Safe.t

        val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t

        val __versioned__ : unit

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t

        val compare : t -> t -> int

        val equal : t -> t -> bool

        val hash_fold_t :
          Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

        val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core.ref -> V1.t)) array

      val bin_read_to_latest_opt :
        Core.Bin_prot.Common.buf -> pos_ref:int Core.ref -> V1.t option
    end

    type nonrec t = Hash.t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    val compare : t -> t -> int

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
  end

  module Stack_versioned : sig
    module Stable : sig
      module V1 : sig
        type nonrec t

        val to_yojson : t -> Yojson.Safe.t

        val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t

        val __versioned__ : unit

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t

        val compare : t -> t -> int

        val equal : t -> t -> bool

        val hash_fold_t :
          Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

        val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core.ref -> V1.t)) array

      val bin_read_to_latest_opt :
        Core.Bin_prot.Common.buf -> pos_ref:int Core.ref -> V1.t option
    end

    type nonrec t = Stable.V1.t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    val compare : t -> t -> int

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
  end

  module Stack : sig
    type t = Stack_versioned.t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    val compare : t -> t -> int

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    type var

    val data_hash : t -> Hash_versioned.t

    val var_of_t : t -> var

    val typ : (var, t) Snark_params.Tick.Typ.t

    val gen : t Core.Quickcheck.Generator.t

    val to_input : t -> (Snark_params.Tick.Field.t, bool) Random_oracle.Input.t

    val to_bits : t -> bool list

    val to_bytes : t -> string

    val equal_var :
         var
      -> var
      -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

    val var_to_input :
         var
      -> ( Snark_params.Tick.Field.Var.t
         , Snark_params.Tick.Boolean.var )
         Random_oracle.Input.t

    val empty : t

    val create_with : t -> t

    val equal_data : t -> t -> bool

    val equal_state_hash : t -> t -> bool

    val push_coinbase : Coinbase.t -> t -> t

    val push_state : State_body_hash.t -> t -> t

    module Checked : sig
      type t = var

      val push_coinbase :
        Coinbase_data.var -> var -> (var, 'a) Snark_params.Tick.Checked.t

      val push_state :
        State_body_hash.var -> var -> (var, 'a) Snark_params.Tick.Checked.t

      val if_ :
           Snark_params.Tick.Boolean.var
        -> then_:var
        -> else_:var
        -> (var, 'a) Snark_params.Tick.Checked.t

      val check_merge :
           transition1:var * var
        -> transition2:var * var
        -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

      val empty : var

      val create_with : var -> var
    end
  end

  module State_stack : sig
    type t
  end

  module Update : sig
    module Action : sig
      module Stable : sig
        module V1 : sig
          type t =
            | Update_none
            | Update_one
            | Update_two_coinbase_in_first
            | Update_two_coinbase_in_second

          val to_yojson : t -> Yojson.Safe.t

          val bin_size_t : t Bin_prot.Size.sizer

          val bin_write_t : t Bin_prot.Write.writer

          val bin_read_t : t Bin_prot.Read.reader

          val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

          val bin_shape_t : Bin_prot.Shape.t

          val bin_writer_t : t Bin_prot.Type_class.writer

          val bin_reader_t : t Bin_prot.Type_class.reader

          val bin_t : t Bin_prot.Type_class.t

          val __versioned__ : unit

          val t_of_sexp : Sexplib0.Sexp.t -> t

          val sexp_of_t : t -> Sexplib0.Sexp.t
        end

        module Latest = V1

        val versions :
          (int * (Core_kernel.Bigstring.t -> pos_ref:int Core.ref -> V1.t))
          array

        val bin_read_to_latest_opt :
          Core.Bin_prot.Common.buf -> pos_ref:int Core.ref -> V1.t option
      end

      type t = Stable.V1.t =
        | Update_none
        | Update_one
        | Update_two_coinbase_in_first
        | Update_two_coinbase_in_second

      val to_yojson : t -> Yojson.Safe.t

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      type var = Snark_params.Tick.Boolean.var * Snark_params.Tick.Boolean.var

      val typ : (var, t) Snark_params.Tick.Typ.t

      val var_of_t : t -> var
    end

    module Poly : sig
      module Stable : sig
        module V1 : sig
          type ('action, 'coinbase_amount) t =
            { action : 'action; coinbase_amount : 'coinbase_amount }

          val bin_shape_t :
            Bin_prot.Shape.t -> Bin_prot.Shape.t -> Bin_prot.Shape.t

          val bin_size_t : ('a, 'b, ('a, 'b) t) Bin_prot.Size.sizer2

          val bin_write_t : ('a, 'b, ('a, 'b) t) Bin_prot.Write.writer2

          val bin_read_t : ('a, 'b, ('a, 'b) t) Bin_prot.Read.reader2

          val __bin_read_t__ : ('a, 'b, int -> ('a, 'b) t) Bin_prot.Read.reader2

          val bin_writer_t : ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.writer

          val bin_reader_t : ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.reader

          val bin_t : ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.t

          val __versioned__ : unit

          val t_of_sexp :
               (Sexplib0.Sexp.t -> 'a)
            -> (Sexplib0.Sexp.t -> 'b)
            -> Sexplib0.Sexp.t
            -> ('a, 'b) t

          val sexp_of_t :
               ('a -> Sexplib0.Sexp.t)
            -> ('b -> Sexplib0.Sexp.t)
            -> ('a, 'b) t
            -> Sexplib0.Sexp.t
        end

        module Latest = V1
      end

      type ('action, 'coinbase_amount) t =
            ('action, 'coinbase_amount) Stable.V1.t =
        { action : 'action; coinbase_amount : 'coinbase_amount }

      val t_of_sexp :
           (Sexplib0.Sexp.t -> 'a)
        -> (Sexplib0.Sexp.t -> 'b)
        -> Sexplib0.Sexp.t
        -> ('a, 'b) t

      val sexp_of_t :
           ('a -> Sexplib0.Sexp.t)
        -> ('b -> Sexplib0.Sexp.t)
        -> ('a, 'b) t
        -> Sexplib0.Sexp.t
    end

    module Stable : sig
      module V1 : sig
        type t = (Action.t, Currency.Amount.Stable.V1.t) Poly.t

        val to_yojson : t -> Yojson.Safe.t

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t

        val __versioned__ : unit

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core.ref -> Latest.t))
        array

      val bin_read_to_latest_opt :
        Core.Bin_prot.Common.buf -> pos_ref:int Core.ref -> Latest.t option
    end

    type t = Stable.Latest.t

    val to_yojson : t -> Yojson.Safe.t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    type var = (Action.var, Currency.Amount.var) Poly.t

    val genesis : t

    val typ : (var, t) Snark_params.Tick.Typ.t

    val var_of_t : t -> var
  end

  val create : depth:int -> unit -> t Core.Or_error.t

  val remove_coinbase_stack :
    depth:int -> t -> (Stack_versioned.t * t) Core.Or_error.t

  val merkle_root : t -> Hash_versioned.t

  val handler :
       depth:int
    -> t
    -> is_new_stack:bool
    -> (Snark_params.Tick.request -> Snark_params.Tick.response) Core.Staged.t

  val update_coinbase_stack :
       depth:int
    -> t
    -> Stack_versioned.t
    -> is_new_stack:bool
    -> t Core.Or_error.t

  val latest_stack : t -> is_new_stack:bool -> Stack_versioned.t Core.Or_error.t

  val oldest_stack : t -> Stack_versioned.t Core.Or_error.t

  val hash_extra : t -> string

  module Checked : sig
    type var = Hash.var

    type path

    module Address : sig
      type value

      type var

      val typ : depth:int -> (var, value) Snark_params.Tick.Typ.t
    end

    type _ Snarky_backendless.Request.t +=
      | Coinbase_stack_path : Address.value -> path Snarky_backendless.Request.t
      | Get_coinbase_stack :
          Address.value
          -> (Stack_versioned.t * path) Snarky_backendless.Request.t
      | Set_coinbase_stack :
          Address.value * Stack_versioned.t
          -> unit Snarky_backendless.Request.t
      | Set_oldest_coinbase_stack :
          Address.value * Stack_versioned.t
          -> unit Snarky_backendless.Request.t
      | Find_index_of_newest_stacks :
          Update.Action.t
          -> (Address.value * Address.value) Snarky_backendless.Request.t
      | Find_index_of_oldest_stack : Address.value Snarky_backendless.Request.t
      | Get_previous_stack : State_stack.t Snarky_backendless.Request.t

    val get :
         depth:int
      -> var
      -> Address.var
      -> (Stack.var, 'a) Snark_params.Tick.Checked.t

    val add_coinbase :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> var
      -> Update.var
      -> coinbase_receiver:Signature_lib.Public_key.Compressed.var
      -> supercharge_coinbase:Snark_params.Tick.Boolean.var
      -> State_body_hash.var
      -> (var, 's) Snark_params.Tick.Checked.t

    val pop_coinbases :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> var
      -> proof_emitted:Snark_params.Tick.Boolean.var
      -> (var * Stack.var, 's) Snark_params.Tick.Checked.t
  end
end
