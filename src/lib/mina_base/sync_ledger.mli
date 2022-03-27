module Hash : sig
  type t = Snark_params.Tick.Field.t

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

  val to_latest : t -> t

  val ( >= ) : t -> t -> bool

  val ( <= ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( < ) : t -> t -> bool

  val ( <> ) : t -> t -> bool

  val equal : t -> t -> bool

  val compare : t -> t -> int

  val min : t -> t -> t

  val max : t -> t -> t

  val ascending : t -> t -> int

  val descending : t -> t -> int

  val between : t -> low:t -> high:t -> bool

  val clamp_exn : t -> min:t -> max:t -> t

  val clamp : t -> min:t -> max:t -> t Base__.Or_error.t

  type comparator_witness = Mina_base__Ledger_hash.Stable.V1.comparator_witness

  val comparator : (t, comparator_witness) Base__.Comparator.comparator

  val validate_lbound : min:t Base__.Maybe_bound.t -> t Base__.Validate.check

  val validate_ubound : max:t Base__.Maybe_bound.t -> t Base__.Validate.check

  val validate_bound :
       min:t Base__.Maybe_bound.t
    -> max:t Base__.Maybe_bound.t
    -> t Base__.Validate.check

  module Replace_polymorphic_compare =
    Mina_base__Ledger_hash.Stable.V1.Replace_polymorphic_compare

  module Map = Mina_base__Ledger_hash.Stable.V1.Map
  module Set = Mina_base__Ledger_hash.Stable.V1.Set

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val hashable : t Core_kernel__.Hashtbl.Hashable.t

  module Table = Mina_base__Ledger_hash.Stable.V1.Table
  module Hash_set = Mina_base__Ledger_hash.Stable.V1.Hash_set
  module Hash_queue = Mina_base__Ledger_hash.Stable.V1.Hash_queue

  val to_base58_check : Ledger_hash.t -> string

  val merge : height:int -> Ledger_hash.t -> Ledger_hash.t -> Ledger_hash.t

  val hash_account : Account.t -> Ledger_hash.t

  val empty_account : Ledger_hash.t
end

module Root_hash : sig
  type t = Hash.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val to_decimal_string : t -> string

  val to_bytes : t -> string

  val gen : t Core_kernel.Quickcheck.Generator.t

  type var = Ledger_hash0.var

  val var_to_hash_packed : var -> Random_oracle.Checked.Digest.t

  val var_to_input :
       var
    -> ( Snark_params.Tick.Field.Var.t
       , Snark_params.Tick.Boolean.var )
       Random_oracle.Input.t

  val var_to_bits :
    var -> (Snark_params.Tick.Boolean.var list, 'a) Snark_params.Tick.Checked.t

  val typ : (var, t) Snark_params.Tick.Typ.t

  val assert_equal : var -> var -> (unit, 'a) Snark_params.Tick.Checked.t

  val equal_var :
       var
    -> var
    -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

  val var_of_t : t -> var

  val fold : t -> bool Fold_lib.Fold.t

  val size_in_bits : int

  val iter : t -> f:(bool -> unit) -> unit

  val to_bits : t -> bool list

  val of_base58_check_exn : string -> t

  val to_input : t -> (t, bool) Random_oracle.Input.t

  val ( >= ) : t -> t -> bool

  val ( <= ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( < ) : t -> t -> bool

  val ( <> ) : t -> t -> bool

  val equal : t -> t -> bool

  val min : t -> t -> t

  val max : t -> t -> t

  val ascending : t -> t -> int

  val descending : t -> t -> int

  val between : t -> low:t -> high:t -> bool

  val clamp_exn : t -> min:t -> max:t -> t

  val clamp : t -> min:t -> max:t -> t Base__.Or_error.t

  type comparator_witness = Mina_base__Ledger_hash.comparator_witness

  val comparator : (t, comparator_witness) Base__.Comparator.comparator

  val validate_lbound : min:t Base__.Maybe_bound.t -> t Base__.Validate.check

  val validate_ubound : max:t Base__.Maybe_bound.t -> t Base__.Validate.check

  val validate_bound :
       min:t Base__.Maybe_bound.t
    -> max:t Base__.Maybe_bound.t
    -> t Base__.Validate.check

  module Replace_polymorphic_compare =
    Mina_base__Ledger_hash.Replace_polymorphic_compare
  module Map = Mina_base__Ledger_hash.Map
  module Set = Mina_base__Ledger_hash.Set

  val compare : t -> t -> Core_kernel__.Import.int

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val hashable : t Core_kernel__.Hashtbl.Hashable.t

  module Table = Mina_base__Ledger_hash.Table
  module Hash_set = Mina_base__Ledger_hash.Hash_set
  module Hash_queue = Mina_base__Ledger_hash.Hash_queue

  val if_ :
       Snark_params.Tick.Boolean.var
    -> then_:var
    -> else_:var
    -> (var, 'a) Snark_params.Tick.Checked.t

  val var_of_hash_packed : Random_oracle.Checked.Digest.t -> var

  val of_hash : t -> t

  module Stable = Mina_base__Ledger_hash.Stable

  type path = Random_oracle.Digest.t list

  type _ Snarky_backendless.Request.t +=
    | Get_path : Account.Index.t -> path Snarky_backendless.Request.t
    | Get_element :
        Account.Index.t
        -> (Account.t * path) Snarky_backendless.Request.t
    | Set : Account.Index.t * Account.t -> unit Snarky_backendless.Request.t
    | Find_index : Account_id.t -> Account.Index.t Snarky_backendless.Request.t

  val get :
       depth:int
    -> var
    -> Account.Index.Unpacked.var
    -> (Account.var, 'a) Snark_params.Tick.Checked.t

  val merge : height:int -> t -> t -> t

  val to_base58_check : t -> string

  val of_base58_check : string -> t Base.Or_error.t

  val empty_hash : t

  val of_digest : Random_oracle.Digest.t -> t

  val modify_account :
       depth:int
    -> var
    -> Account_id.var
    -> filter:(Account.var -> ('a, 's) Snark_params.Tick.Checked.t)
    -> f:('a -> Account.var -> (Account.var, 's) Snark_params.Tick.Checked.t)
    -> (var, 's) Snark_params.Tick.Checked.t

  val modify_account_send :
       depth:int
    -> var
    -> Account_id.var
    -> is_writeable:Snark_params.Tick.Boolean.var
    -> f:
         (   is_empty_and_writeable:Snark_params.Tick.Boolean.var
          -> Account.var
          -> (Account.var, 's) Snark_params.Tick.Checked.t)
    -> (var, 's) Snark_params.Tick.Checked.t

  val modify_account_recv :
       depth:int
    -> var
    -> Account_id.var
    -> f:
         (   is_empty_and_writeable:Snark_params.Tick.Boolean.var
          -> Account.var
          -> (Account.var, 's) Snark_params.Tick.Checked.t)
    -> (var, 's) Snark_params.Tick.Checked.t

  val to_hash : t -> Ledger_hash.t
end

module Mask : sig
  type 'a t

  val t_of_sexp : (Sexplib0.Sexp.t -> 'a) -> Sexplib0.Sexp.t -> 'a t

  val sexp_of_t : ('a -> Sexplib0.Sexp.t) -> 'a t -> Sexplib0.Sexp.t

  type diff

  type index = int

  module Responder : sig
    type t

    val create :
         Mina_base__Ledger.Mask.Attached.t
      -> (Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t -> unit)
      -> logger:Logger.t
      -> trust_system:Trust_system.t
      -> t

    val answer_query :
         t
      -> Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t
         Network_peer.Envelope.Incoming.t
      -> ( Root_hash.t
         , Mina_base__Account.Binable_arg.Stable.V1.t )
         Syncable_ledger.Answer.t
         option
         Async_kernel.Deferred.t
  end

  val create :
       Mina_base__Ledger.Mask.Attached.t
    -> logger:Logger.t
    -> trust_system:Trust_system.t
    -> 'a t

  val answer_writer :
       'a t
    -> ( Root_hash.t
       * Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t
       * ( Root_hash.t
         , Mina_base__Account.Binable_arg.Stable.V1.t )
         Syncable_ledger.Answer.t
         Network_peer.Envelope.Incoming.t )
       Pipe_lib.Linear_pipe.Writer.t

  val query_reader :
       'a t
    -> (Root_hash.t * Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t)
       Pipe_lib.Linear_pipe.Reader.t

  val destroy : 'a t -> unit

  val new_goal :
       'a t
    -> Root_hash.t
    -> data:'a
    -> equal:('a -> 'a -> bool)
    -> [ `New | `Repeat | `Update_data ]

  val peek_valid_tree : 'a t -> Mina_base__Ledger.Mask.Attached.t option

  val valid_tree :
    'a t -> (Mina_base__Ledger.Mask.Attached.t * 'a) Async_kernel.Deferred.t

  val wait_until_valid :
       'a t
    -> Root_hash.t
    -> [ `Ok of Mina_base__Ledger.Mask.Attached.t
       | `Target_changed of Root_hash.t option * Root_hash.t ]
       Async_kernel.Deferred.t

  val fetch :
       'a t
    -> Root_hash.t
    -> data:'a
    -> equal:('a -> 'a -> bool)
    -> [ `Ok of Mina_base__Ledger.Mask.Attached.t
       | `Target_changed of Root_hash.t option * Root_hash.t ]
       Async_kernel.Deferred.t

  val apply_or_queue_diff : 'a t -> diff -> unit

  val merkle_path_at_addr :
       'a t
    -> Mina_base__Ledger.Location.Addr.t
    -> [ `Left of Ledger_hash.t | `Right of Ledger_hash.t ] list
       Core_kernel.Or_error.t

  val get_account_at_addr :
       'a t
    -> Mina_base__Ledger.Location.Addr.t
    -> Mina_base__Account.Binable_arg.Stable.V1.t Core_kernel.Or_error.t
end

module Any_ledger : sig
  type 'a t

  val t_of_sexp : (Sexplib0.Sexp.t -> 'a) -> Sexplib0.Sexp.t -> 'a t

  val sexp_of_t : ('a -> Sexplib0.Sexp.t) -> 'a t -> Sexplib0.Sexp.t

  type diff

  type index = Mask.index

  module Responder : sig
    type t

    val create :
         Mina_base__Ledger.Any_ledger.witness
      -> (Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t -> unit)
      -> logger:Logger.t
      -> trust_system:Trust_system.t
      -> t

    val answer_query :
         t
      -> Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t
         Network_peer.Envelope.Incoming.t
      -> ( Root_hash.t
         , Mina_base__Account.Binable_arg.Stable.V1.t )
         Syncable_ledger.Answer.t
         option
         Async_kernel.Deferred.t
  end

  val create :
       Mina_base__Ledger.Any_ledger.witness
    -> logger:Logger.t
    -> trust_system:Trust_system.t
    -> 'a t

  val answer_writer :
       'a t
    -> ( Root_hash.t
       * Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t
       * ( Root_hash.t
         , Mina_base__Account.Binable_arg.Stable.V1.t )
         Syncable_ledger.Answer.t
         Network_peer.Envelope.Incoming.t )
       Pipe_lib.Linear_pipe.Writer.t

  val query_reader :
       'a t
    -> (Root_hash.t * Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t)
       Pipe_lib.Linear_pipe.Reader.t

  val destroy : 'a t -> unit

  val new_goal :
       'a t
    -> Root_hash.t
    -> data:'a
    -> equal:('a -> 'a -> bool)
    -> [ `New | `Repeat | `Update_data ]

  val peek_valid_tree : 'a t -> Mina_base__Ledger.Any_ledger.witness option

  val valid_tree :
    'a t -> (Mina_base__Ledger.Any_ledger.witness * 'a) Async_kernel.Deferred.t

  val wait_until_valid :
       'a t
    -> Root_hash.t
    -> [ `Ok of Mina_base__Ledger.Any_ledger.witness
       | `Target_changed of Root_hash.t option * Root_hash.t ]
       Async_kernel.Deferred.t

  val fetch :
       'a t
    -> Root_hash.t
    -> data:'a
    -> equal:('a -> 'a -> bool)
    -> [ `Ok of Mina_base__Ledger.Any_ledger.witness
       | `Target_changed of Root_hash.t option * Root_hash.t ]
       Async_kernel.Deferred.t

  val apply_or_queue_diff : 'a t -> diff -> unit

  val merkle_path_at_addr :
       'a t
    -> Mina_base__Ledger.Location.Addr.t
    -> [ `Left of Ledger_hash.t | `Right of Ledger_hash.t ] list
       Core_kernel.Or_error.t

  val get_account_at_addr :
       'a t
    -> Mina_base__Ledger.Location.Addr.t
    -> Mina_base__Account.Binable_arg.Stable.V1.t Core_kernel.Or_error.t
end

module Db : sig
  type 'a t

  val t_of_sexp : (Sexplib0.Sexp.t -> 'a) -> Sexplib0.Sexp.t -> 'a t

  val sexp_of_t : ('a -> Sexplib0.Sexp.t) -> 'a t -> Sexplib0.Sexp.t

  type diff

  type index = Mask.index

  module Responder : sig
    type t

    val create :
         Mina_base__Ledger.Db.t
      -> (Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t -> unit)
      -> logger:Logger.t
      -> trust_system:Trust_system.t
      -> t

    val answer_query :
         t
      -> Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t
         Network_peer.Envelope.Incoming.t
      -> ( Root_hash.t
         , Mina_base__Account.Binable_arg.Stable.V1.t )
         Syncable_ledger.Answer.t
         option
         Async_kernel.Deferred.t
  end

  val create :
       Mina_base__Ledger.Db.t
    -> logger:Logger.t
    -> trust_system:Trust_system.t
    -> 'a t

  val answer_writer :
       'a t
    -> ( Root_hash.t
       * Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t
       * ( Root_hash.t
         , Mina_base__Account.Binable_arg.Stable.V1.t )
         Syncable_ledger.Answer.t
         Network_peer.Envelope.Incoming.t )
       Pipe_lib.Linear_pipe.Writer.t

  val query_reader :
       'a t
    -> (Root_hash.t * Mina_base__Ledger.Location.Addr.t Syncable_ledger.Query.t)
       Pipe_lib.Linear_pipe.Reader.t

  val destroy : 'a t -> unit

  val new_goal :
       'a t
    -> Root_hash.t
    -> data:'a
    -> equal:('a -> 'a -> bool)
    -> [ `New | `Repeat | `Update_data ]

  val peek_valid_tree : 'a t -> Mina_base__Ledger.Db.t option

  val valid_tree : 'a t -> (Mina_base__Ledger.Db.t * 'a) Async_kernel.Deferred.t

  val wait_until_valid :
       'a t
    -> Root_hash.t
    -> [ `Ok of Mina_base__Ledger.Db.t
       | `Target_changed of Root_hash.t option * Root_hash.t ]
       Async_kernel.Deferred.t

  val fetch :
       'a t
    -> Root_hash.t
    -> data:'a
    -> equal:('a -> 'a -> bool)
    -> [ `Ok of Mina_base__Ledger.Db.t
       | `Target_changed of Root_hash.t option * Root_hash.t ]
       Async_kernel.Deferred.t

  val apply_or_queue_diff : 'a t -> diff -> unit

  val merkle_path_at_addr :
       'a t
    -> Mina_base__Ledger.Location.Addr.t
    -> [ `Left of Ledger_hash.t | `Right of Ledger_hash.t ] list
       Core_kernel.Or_error.t

  val get_account_at_addr :
       'a t
    -> Mina_base__Ledger.Location.Addr.t
    -> Mina_base__Account.Binable_arg.Stable.V1.t Core_kernel.Or_error.t
end

module Answer : sig
  module Stable : sig
    module V1 : sig
      type t =
        ( Ledger_hash.Stable.V1.t
        , Account.Stable.V1.t )
        Syncable_ledger.Answer.Stable.V1.t

      val to_yojson : t -> Yojson.Safe.t

      val version : Mask.index

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val to_latest : 'a -> 'a

      module With_version : sig
        type typ = t

        val bin_shape_typ : Core_kernel.Bin_prot.Shape.t

        val bin_size_typ : typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ : typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ : typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
          (Mask.index -> typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ : typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ : typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ : typ Core_kernel.Bin_prot.Type_class.t

        type t = { version : Mask.index; t : typ }

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t : t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ : (Mask.index -> t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t : t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

        val create : typ -> t
      end

      val bin_read_t :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

      val __bin_read_t__ :
           Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> Mask.index
        -> t

      val bin_size_t : t -> Mask.index

      val bin_write_t :
           Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> t
        -> Bin_prot.Common.pos

      val bin_shape_t : Core_kernel.Bin_prot.Shape.t

      val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

      val bin_t : t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t)
        * (   Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> Mask.index
           -> t)
        * (t -> Mask.index)
        * (   Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> t
           -> Bin_prot.Common.pos)
        * Core_kernel.Bin_prot.Shape.t
        * t Core_kernel.Bin_prot.Type_class.reader
        * t Core_kernel.Bin_prot.Type_class.writer
        * t Core_kernel.Bin_prot.Type_class.t
    end

    module Latest = V1

    val versions :
      ( Mask.index
      * (   Core_kernel.Bigstring.t
         -> pos_ref:Mask.index Core_kernel.ref
         -> Latest.t) )
      array

    val bin_read_to_latest_opt :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> Latest.t option

    val __ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> Latest.t option
  end

  type t = Stable.Latest.t

  val to_yojson : t -> Yojson.Safe.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
end

module Query : sig
  module Stable : sig
    module V1 : sig
      type t =
        Ledger.Location.Addr.Stable.V1.t Syncable_ledger.Query.Stable.V1.t

      val to_yojson : t -> Yojson.Safe.t

      val version : Mask.index

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val compare : t -> t -> Mask.index

      val to_latest : 'a -> 'a

      module With_version : sig
        type typ = t

        val bin_shape_typ : Core_kernel.Bin_prot.Shape.t

        val bin_size_typ : typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ : typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ : typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
          (Mask.index -> typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ : typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ : typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ : typ Core_kernel.Bin_prot.Type_class.t

        type t = { version : Mask.index; t : typ }

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t : t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ : (Mask.index -> t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t : t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

        val create : typ -> t
      end

      val bin_read_t :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

      val __bin_read_t__ :
           Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> Mask.index
        -> t

      val bin_size_t : t -> Mask.index

      val bin_write_t :
           Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> t
        -> Bin_prot.Common.pos

      val bin_shape_t : Core_kernel.Bin_prot.Shape.t

      val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

      val bin_t : t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t)
        * (   Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> Mask.index
           -> t)
        * (t -> Mask.index)
        * (   Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> t
           -> Bin_prot.Common.pos)
        * Core_kernel.Bin_prot.Shape.t
        * t Core_kernel.Bin_prot.Type_class.reader
        * t Core_kernel.Bin_prot.Type_class.writer
        * t Core_kernel.Bin_prot.Type_class.t
    end

    module Latest = V1

    val versions :
      ( Mask.index
      * (   Core_kernel.Bigstring.t
         -> pos_ref:Mask.index Core_kernel.ref
         -> Latest.t) )
      array

    val bin_read_to_latest_opt :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> Latest.t option

    val __ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> Latest.t option
  end

  type t = Stable.Latest.t

  val to_yojson : t -> Yojson.Safe.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> Mask.index
end
