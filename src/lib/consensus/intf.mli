module type Constants = sig
  module Stable : sig
    module V1 : sig
      type t

      val bin_size_t : t Bin_prot.Size.sizer

      val bin_write_t : t Bin_prot.Write.writer

      val bin_read_t : t Bin_prot.Read.reader

      val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

      val bin_shape_t : Bin_prot.Shape.t

      val bin_writer_t : t Bin_prot.Type_class.writer

      val bin_reader_t : t Bin_prot.Type_class.reader

      val bin_t : t Bin_prot.Type_class.t

      val __versioned__ : unit
    end

    module Latest = V1

    val versions :
      (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
      array

    val bin_read_to_latest_opt :
         Core_kernel.Bin_prot.Common.buf
      -> pos_ref:int Core_kernel.ref
      -> V1.t option
  end

  type t = Stable.V1.t

  val create : protocol_constants:Genesis_constants.Protocol.t -> t

  val gc_parameters :
       t
    -> [ `Acceptable_network_delay of Mina_numbers.Length.t ]
       * [ `Gc_width of Mina_numbers.Length.t ]
       * [ `Gc_width_epoch of Mina_numbers.Length.t ]
       * [ `Gc_width_slot of Mina_numbers.Length.t ]
       * [ `Gc_interval of Mina_numbers.Length.t ]
end

module type Blockchain_state = sig
  module Poly : sig
    module Stable : sig
      module V1 : sig
        type ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'staged_ledger_hash Core_kernel.Bin_prot.Size.sizer
          -> 'snarked_ledger_hash Core_kernel.Bin_prot.Size.sizer
          -> 'token_id Core_kernel.Bin_prot.Size.sizer
          -> 'time Core_kernel.Bin_prot.Size.sizer
          -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
             Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'staged_ledger_hash Core_kernel.Bin_prot.Write.writer
          -> 'snarked_ledger_hash Core_kernel.Bin_prot.Write.writer
          -> 'token_id Core_kernel.Bin_prot.Write.writer
          -> 'time Core_kernel.Bin_prot.Write.writer
          -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
             Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'staged_ledger_hash Core_kernel.Bin_prot.Type_class.writer
          -> 'snarked_ledger_hash Core_kernel.Bin_prot.Type_class.writer
          -> 'token_id Core_kernel.Bin_prot.Type_class.writer
          -> 'time Core_kernel.Bin_prot.Type_class.writer
          -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
             Core_kernel.Bin_prot.Type_class.writer

        val bin_read_t :
             'staged_ledger_hash Core_kernel.Bin_prot.Read.reader
          -> 'snarked_ledger_hash Core_kernel.Bin_prot.Read.reader
          -> 'token_id Core_kernel.Bin_prot.Read.reader
          -> 'time Core_kernel.Bin_prot.Read.reader
          -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
             Core_kernel.Bin_prot.Read.reader

        val __bin_read_t__ :
             'staged_ledger_hash Core_kernel.Bin_prot.Read.reader
          -> 'snarked_ledger_hash Core_kernel.Bin_prot.Read.reader
          -> 'token_id Core_kernel.Bin_prot.Read.reader
          -> 'time Core_kernel.Bin_prot.Read.reader
          -> (   int
              -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t)
             Core_kernel.Bin_prot.Read.reader

        val bin_reader_t :
             'staged_ledger_hash Core_kernel.Bin_prot.Type_class.reader
          -> 'snarked_ledger_hash Core_kernel.Bin_prot.Type_class.reader
          -> 'token_id Core_kernel.Bin_prot.Type_class.reader
          -> 'time Core_kernel.Bin_prot.Type_class.reader
          -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
             Core_kernel.Bin_prot.Type_class.reader

        val bin_t :
             'staged_ledger_hash Core_kernel.Bin_prot.Type_class.t
          -> 'snarked_ledger_hash Core_kernel.Bin_prot.Type_class.t
          -> 'token_id Core_kernel.Bin_prot.Type_class.t
          -> 'time Core_kernel.Bin_prot.Type_class.t
          -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
             Core_kernel.Bin_prot.Type_class.t

        val __versioned__ : unit

        val sexp_of_t :
             ('staged_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('snarked_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('time -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
          -> Ppx_sexp_conv_lib.Sexp.t

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'staged_ledger_hash)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'snarked_ledger_hash)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'time)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
      end

      module Latest = V1
    end

    type ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t =
      ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) Stable.V1.t

    val sexp_of_t :
         ('staged_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('snarked_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('time -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'staged_ledger_hash)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'snarked_ledger_hash)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'time)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
  end

  module Value : sig
    module Stable : sig
      module V1 : sig
        type t =
          ( Mina_base.Staged_ledger_hash.t
          , Mina_base.Frozen_ledger_hash.t
          , Mina_base.Token_id.t
          , Block_time.t )
          Poly.t

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
        ( int
        * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
        )
        array

      val bin_read_to_latest_opt :
           Core_kernel.Bin_prot.Common.buf
        -> pos_ref:int Core_kernel.ref
        -> Latest.t option
    end

    type t = Stable.Latest.t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t
  end

  type var =
    ( Mina_base.Staged_ledger_hash.var
    , Mina_base.Frozen_ledger_hash.var
    , Mina_base.Token_id.var
    , Block_time.Unpacked.var )
    Poly.t

  val create_value :
       staged_ledger_hash:Mina_base.Staged_ledger_hash.t
    -> snarked_ledger_hash:Mina_base.Frozen_ledger_hash.t
    -> genesis_ledger_hash:Mina_base.Frozen_ledger_hash.t
    -> snarked_next_available_token:Mina_base.Token_id.t
    -> timestamp:Block_time.t
    -> Value.t

  val staged_ledger_hash :
    ('staged_ledger_hash, 'a, 'b, 'c) Poly.t -> 'staged_ledger_hash

  val snarked_ledger_hash :
    ('a, 'frozen_ledger_hash, 'b, 'c) Poly.t -> 'frozen_ledger_hash

  val genesis_ledger_hash :
    ('a, 'frozen_ledger_hash, 'b, 'c) Poly.t -> 'frozen_ledger_hash

  val snarked_next_available_token : ('a, 'b, 'token_id, 'c) Poly.t -> 'token_id

  val timestamp : ('a, 'b, 'c, 'time) Poly.t -> 'time
end

module type Protocol_state = sig
  type blockchain_state

  type blockchain_state_var

  type consensus_state

  type consensus_state_var

  module Poly : sig
    module Stable : sig
      module V1 : sig
        type ('state_hash, 'body) t

        val to_yojson :
             ('state_hash -> Yojson.Safe.t)
          -> ('body -> Yojson.Safe.t)
          -> ('state_hash, 'body) t
          -> Yojson.Safe.t

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

        val equal :
             ('state_hash -> 'state_hash -> bool)
          -> ('body -> 'body -> bool)
          -> ('state_hash, 'body) t
          -> ('state_hash, 'body) t
          -> bool

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'state_hash
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'body
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ('state_hash, 'body) t
          -> Ppx_hash_lib.Std.Hash.state

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

    type ('state_hash, 'body) t = ('state_hash, 'body) Stable.V1.t

    val to_yojson :
         ('state_hash -> Yojson.Safe.t)
      -> ('body -> Yojson.Safe.t)
      -> ('state_hash, 'body) t
      -> Yojson.Safe.t

    val equal :
         ('state_hash -> 'state_hash -> bool)
      -> ('body -> 'body -> bool)
      -> ('state_hash, 'body) t
      -> ('state_hash, 'body) t
      -> bool

    val hash_fold_t :
         (   Ppx_hash_lib.Std.Hash.state
          -> 'state_hash
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'body -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ('state_hash, 'body) t
      -> Ppx_hash_lib.Std.Hash.state

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

  module Body : sig
    module Poly : sig
      module Stable : sig
        module V1 : sig
          type ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_t :
               'state_hash Core_kernel.Bin_prot.Size.sizer
            -> 'blockchain_state Core_kernel.Bin_prot.Size.sizer
            -> 'consensus_state Core_kernel.Bin_prot.Size.sizer
            -> 'constants Core_kernel.Bin_prot.Size.sizer
            -> ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_t :
               'state_hash Core_kernel.Bin_prot.Write.writer
            -> 'blockchain_state Core_kernel.Bin_prot.Write.writer
            -> 'consensus_state Core_kernel.Bin_prot.Write.writer
            -> 'constants Core_kernel.Bin_prot.Write.writer
            -> ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_t :
               'state_hash Core_kernel.Bin_prot.Type_class.writer
            -> 'blockchain_state Core_kernel.Bin_prot.Type_class.writer
            -> 'consensus_state Core_kernel.Bin_prot.Type_class.writer
            -> 'constants Core_kernel.Bin_prot.Type_class.writer
            -> ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
               Core_kernel.Bin_prot.Type_class.writer

          val bin_read_t :
               'state_hash Core_kernel.Bin_prot.Read.reader
            -> 'blockchain_state Core_kernel.Bin_prot.Read.reader
            -> 'consensus_state Core_kernel.Bin_prot.Read.reader
            -> 'constants Core_kernel.Bin_prot.Read.reader
            -> ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
               Core_kernel.Bin_prot.Read.reader

          val __bin_read_t__ :
               'state_hash Core_kernel.Bin_prot.Read.reader
            -> 'blockchain_state Core_kernel.Bin_prot.Read.reader
            -> 'consensus_state Core_kernel.Bin_prot.Read.reader
            -> 'constants Core_kernel.Bin_prot.Read.reader
            -> (   int
                -> ( 'state_hash
                   , 'blockchain_state
                   , 'consensus_state
                   , 'constants )
                   t)
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_t :
               'state_hash Core_kernel.Bin_prot.Type_class.reader
            -> 'blockchain_state Core_kernel.Bin_prot.Type_class.reader
            -> 'consensus_state Core_kernel.Bin_prot.Type_class.reader
            -> 'constants Core_kernel.Bin_prot.Type_class.reader
            -> ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
               Core_kernel.Bin_prot.Type_class.reader

          val bin_t :
               'state_hash Core_kernel.Bin_prot.Type_class.t
            -> 'blockchain_state Core_kernel.Bin_prot.Type_class.t
            -> 'consensus_state Core_kernel.Bin_prot.Type_class.t
            -> 'constants Core_kernel.Bin_prot.Type_class.t
            -> ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
               Core_kernel.Bin_prot.Type_class.t

          val __versioned__ : unit

          val sexp_of_t :
               ('state_hash -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('blockchain_state -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('consensus_state -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('constants -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
            -> Ppx_sexp_conv_lib.Sexp.t

          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'state_hash)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'blockchain_state)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'consensus_state)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'constants)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
        end

        module Latest = V1
      end

      type ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t =
        ( 'state_hash
        , 'blockchain_state
        , 'consensus_state
        , 'constants )
        Stable.V1.t

      val sexp_of_t :
           ('state_hash -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('blockchain_state -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('consensus_state -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('constants -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'state_hash)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'blockchain_state)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'consensus_state)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'constants)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
    end

    module Value : sig
      module Stable : sig
        module V1 : sig
          type t =
            ( Mina_base.State_hash.t
            , blockchain_state
            , consensus_state
            , Mina_base.Protocol_constants_checked.Value.Stable.V1.t )
            Poly.t

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
          ( int
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
          )
          array

        val bin_read_to_latest_opt :
             Core_kernel.Bin_prot.Common.buf
          -> pos_ref:int Core_kernel.ref
          -> Latest.t option
      end

      type t = Stable.Latest.t

      val to_yojson : t -> Yojson.Safe.t

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    type var =
      ( Mina_base.State_hash.var
      , blockchain_state_var
      , consensus_state_var
      , Mina_base.Protocol_constants_checked.var )
      Poly.t
  end

  module Value : sig
    module Stable : sig
      module V1 : sig
        type t = (Mina_base.State_hash.t, Body.Value.Stable.V1.t) Poly.t

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

        val equal : t -> t -> bool

        val compare : t -> t -> int
      end

      module Latest = V1

      val versions :
        ( int
        * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
        )
        array

      val bin_read_to_latest_opt :
           Core_kernel.Bin_prot.Common.buf
        -> pos_ref:int Core_kernel.ref
        -> Latest.t option
    end

    type t = Stable.Latest.t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    val equal : t -> t -> bool

    val compare : t -> t -> int
  end

  type var = (Mina_base.State_hash.var, Body.var) Poly.t

  val create_value :
       previous_state_hash:Mina_base.State_hash.t
    -> genesis_state_hash:Mina_base.State_hash.t
    -> blockchain_state:blockchain_state
    -> consensus_state:consensus_state
    -> constants:Mina_base.Protocol_constants_checked.Value.t
    -> Value.t

  val previous_state_hash : ('state_hash, 'a) Poly.t -> 'state_hash

  val body : ('a, 'body) Poly.t -> 'body

  val blockchain_state :
       ('a, ('b, 'blockchain_state, 'c, 'd) Body.Poly.t) Poly.t
    -> 'blockchain_state

  val genesis_state_hash :
       ?state_hash:Mina_base.State_hash.t option
    -> Value.t
    -> Mina_base.State_hash.t

  val consensus_state :
    ('a, ('b, 'c, 'consensus_state, 'd) Body.Poly.t) Poly.t -> 'consensus_state

  val constants :
    ('a, ('b, 'c, 'd, 'constants) Body.Poly.t) Poly.t -> 'constants

  val hash : Value.t -> Mina_base.State_hash.t
end

module type Snark_transition = sig
  type blockchain_state_var

  type consensus_transition_var

  module Poly : sig
    type ('blockchain_state, 'consensus_transition, 'pending_coinbase_update) t

    val t_of_sexp :
         (Sexplib0.Sexp.t -> 'a)
      -> (Sexplib0.Sexp.t -> 'b)
      -> (Sexplib0.Sexp.t -> 'c)
      -> Sexplib0.Sexp.t
      -> ('a, 'b, 'c) t

    val sexp_of_t :
         ('a -> Sexplib0.Sexp.t)
      -> ('b -> Sexplib0.Sexp.t)
      -> ('c -> Sexplib0.Sexp.t)
      -> ('a, 'b, 'c) t
      -> Sexplib0.Sexp.t
  end

  module Value : sig
    type t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t
  end

  type var =
    ( blockchain_state_var
    , consensus_transition_var
    , Mina_base.Pending_coinbase.Update.var )
    Poly.t

  val consensus_transition :
    ('a, 'consensus_transition, 'b) Poly.t -> 'consensus_transition

  val blockchain_state : ('blockchain_state, 'a, 'b) Poly.t -> 'blockchain_state
end

module type State_hooks = sig
  type consensus_state

  type consensus_state_var

  type consensus_transition

  type block_data

  type blockchain_state

  type protocol_state

  type protocol_state_var

  type snark_transition_var

  val generate_transition :
       previous_protocol_state:protocol_state
    -> blockchain_state:blockchain_state
    -> current_time:Unix_timestamp.t
    -> block_data:block_data
    -> supercharge_coinbase:bool
    -> snarked_ledger_hash:Mina_base.Frozen_ledger_hash.t
    -> genesis_ledger_hash:Mina_base.Frozen_ledger_hash.t
    -> supply_increase:Currency.Amount.t
    -> logger:Logger.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> protocol_state * consensus_transition

  val next_state_checked :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> prev_state:protocol_state_var
    -> prev_state_hash:Mina_base.State_hash.var
    -> snark_transition_var
    -> Currency.Amount.var
    -> ( [ `Success of Snark_params.Tick.Boolean.var ] * consensus_state_var
       , 'a )
       Snark_params.Tick.Checked.t

  val genesis_winner :
    Signature_lib.Public_key.Compressed.t * Signature_lib.Private_key.t

  module For_tests : sig
    val gen_consensus_state :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> constants:Constants.t
      -> gen_slot_advancement:int Async.Quickcheck.Generator.t
      -> (   previous_protocol_state:
               protocol_state Mina_base.State_hash.With_state_hashes.t
          -> snarked_ledger_hash:Mina_base.Frozen_ledger_hash.t
          -> coinbase_receiver:Signature_lib.Public_key.Compressed.t
          -> supercharge_coinbase:bool
          -> consensus_state)
         Async.Quickcheck.Generator.t
  end
end

module type S = sig
  val name : string

  val time_hum : constants:Constants.t -> Block_time.t -> string

  module Constants = Constants

  module Configuration : sig
    module Stable : sig
      module V1 : sig
        type t =
          { delta : int
          ; k : int
          ; slots_per_epoch : int
          ; slot_duration : int
          ; epoch_duration : int
          ; genesis_state_timestamp : Block_time.Stable.V1.t
          ; acceptable_network_delay : int
          }

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

        val acceptable_network_delay : t -> int

        val genesis_state_timestamp : t -> Block_time.Stable.V1.t

        val epoch_duration : t -> int

        val slot_duration : t -> int

        val slots_per_epoch : t -> int

        val k : t -> int

        val delta : t -> int

        module Fields : sig
          val names : string list

          val acceptable_network_delay : (t, int) Fieldslib.Field.t

          val genesis_state_timestamp :
            (t, Block_time.Stable.V1.t) Fieldslib.Field.t

          val epoch_duration : (t, int) Fieldslib.Field.t

          val slot_duration : (t, int) Fieldslib.Field.t

          val slots_per_epoch : (t, int) Fieldslib.Field.t

          val k : (t, int) Fieldslib.Field.t

          val delta : (t, int) Fieldslib.Field.t

          val fold :
               init:'acc__0
            -> delta:('acc__0 -> (t, int) Fieldslib.Field.t -> 'acc__1)
            -> k:('acc__1 -> (t, int) Fieldslib.Field.t -> 'acc__2)
            -> slots_per_epoch:
                 ('acc__2 -> (t, int) Fieldslib.Field.t -> 'acc__3)
            -> slot_duration:('acc__3 -> (t, int) Fieldslib.Field.t -> 'acc__4)
            -> epoch_duration:('acc__4 -> (t, int) Fieldslib.Field.t -> 'acc__5)
            -> genesis_state_timestamp:
                 (   'acc__5
                  -> (t, Block_time.Stable.V1.t) Fieldslib.Field.t
                  -> 'acc__6)
            -> acceptable_network_delay:
                 ('acc__6 -> (t, int) Fieldslib.Field.t -> 'acc__7)
            -> 'acc__7

          val make_creator :
               delta:
                 (   (t, int) Fieldslib.Field.t
                  -> 'acc__0
                  -> ('input__ -> int) * 'acc__1)
            -> k:
                 (   (t, int) Fieldslib.Field.t
                  -> 'acc__1
                  -> ('input__ -> int) * 'acc__2)
            -> slots_per_epoch:
                 (   (t, int) Fieldslib.Field.t
                  -> 'acc__2
                  -> ('input__ -> int) * 'acc__3)
            -> slot_duration:
                 (   (t, int) Fieldslib.Field.t
                  -> 'acc__3
                  -> ('input__ -> int) * 'acc__4)
            -> epoch_duration:
                 (   (t, int) Fieldslib.Field.t
                  -> 'acc__4
                  -> ('input__ -> int) * 'acc__5)
            -> genesis_state_timestamp:
                 (   (t, Block_time.Stable.V1.t) Fieldslib.Field.t
                  -> 'acc__5
                  -> ('input__ -> Block_time.Stable.V1.t) * 'acc__6)
            -> acceptable_network_delay:
                 (   (t, int) Fieldslib.Field.t
                  -> 'acc__6
                  -> ('input__ -> int) * 'acc__7)
            -> 'acc__0
            -> ('input__ -> t) * 'acc__7

          val create :
               delta:int
            -> k:int
            -> slots_per_epoch:int
            -> slot_duration:int
            -> epoch_duration:int
            -> genesis_state_timestamp:Block_time.Stable.V1.t
            -> acceptable_network_delay:int
            -> t

          val map :
               delta:((t, int) Fieldslib.Field.t -> int)
            -> k:((t, int) Fieldslib.Field.t -> int)
            -> slots_per_epoch:((t, int) Fieldslib.Field.t -> int)
            -> slot_duration:((t, int) Fieldslib.Field.t -> int)
            -> epoch_duration:((t, int) Fieldslib.Field.t -> int)
            -> genesis_state_timestamp:
                 (   (t, Block_time.Stable.V1.t) Fieldslib.Field.t
                  -> Block_time.Stable.V1.t)
            -> acceptable_network_delay:((t, int) Fieldslib.Field.t -> int)
            -> t

          val iter :
               delta:((t, int) Fieldslib.Field.t -> unit)
            -> k:((t, int) Fieldslib.Field.t -> unit)
            -> slots_per_epoch:((t, int) Fieldslib.Field.t -> unit)
            -> slot_duration:((t, int) Fieldslib.Field.t -> unit)
            -> epoch_duration:((t, int) Fieldslib.Field.t -> unit)
            -> genesis_state_timestamp:
                 ((t, Block_time.Stable.V1.t) Fieldslib.Field.t -> unit)
            -> acceptable_network_delay:((t, int) Fieldslib.Field.t -> unit)
            -> unit

          val for_all :
               delta:((t, int) Fieldslib.Field.t -> bool)
            -> k:((t, int) Fieldslib.Field.t -> bool)
            -> slots_per_epoch:((t, int) Fieldslib.Field.t -> bool)
            -> slot_duration:((t, int) Fieldslib.Field.t -> bool)
            -> epoch_duration:((t, int) Fieldslib.Field.t -> bool)
            -> genesis_state_timestamp:
                 ((t, Block_time.Stable.V1.t) Fieldslib.Field.t -> bool)
            -> acceptable_network_delay:((t, int) Fieldslib.Field.t -> bool)
            -> bool

          val exists :
               delta:((t, int) Fieldslib.Field.t -> bool)
            -> k:((t, int) Fieldslib.Field.t -> bool)
            -> slots_per_epoch:((t, int) Fieldslib.Field.t -> bool)
            -> slot_duration:((t, int) Fieldslib.Field.t -> bool)
            -> epoch_duration:((t, int) Fieldslib.Field.t -> bool)
            -> genesis_state_timestamp:
                 ((t, Block_time.Stable.V1.t) Fieldslib.Field.t -> bool)
            -> acceptable_network_delay:((t, int) Fieldslib.Field.t -> bool)
            -> bool

          val to_list :
               delta:((t, int) Fieldslib.Field.t -> 'elem__)
            -> k:((t, int) Fieldslib.Field.t -> 'elem__)
            -> slots_per_epoch:((t, int) Fieldslib.Field.t -> 'elem__)
            -> slot_duration:((t, int) Fieldslib.Field.t -> 'elem__)
            -> epoch_duration:((t, int) Fieldslib.Field.t -> 'elem__)
            -> genesis_state_timestamp:
                 ((t, Block_time.Stable.V1.t) Fieldslib.Field.t -> 'elem__)
            -> acceptable_network_delay:((t, int) Fieldslib.Field.t -> 'elem__)
            -> 'elem__ list

          val map_poly :
               ([< `Read | `Set_and_create ], t, 'x0) Fieldslib.Field.user
            -> 'x0 list

          module Direct : sig
            val iter :
                 t
              -> delta:((t, int) Fieldslib.Field.t -> t -> int -> unit)
              -> k:((t, int) Fieldslib.Field.t -> t -> int -> unit)
              -> slots_per_epoch:
                   ((t, int) Fieldslib.Field.t -> t -> int -> unit)
              -> slot_duration:((t, int) Fieldslib.Field.t -> t -> int -> unit)
              -> epoch_duration:((t, int) Fieldslib.Field.t -> t -> int -> unit)
              -> genesis_state_timestamp:
                   (   (t, Block_time.Stable.V1.t) Fieldslib.Field.t
                    -> t
                    -> Block_time.Stable.V1.t
                    -> unit)
              -> acceptable_network_delay:
                   ((t, int) Fieldslib.Field.t -> t -> int -> unit)
              -> unit

            val fold :
                 t
              -> init:'acc__0
              -> delta:
                   (   'acc__0
                    -> (t, int) Fieldslib.Field.t
                    -> t
                    -> int
                    -> 'acc__1)
              -> k:
                   (   'acc__1
                    -> (t, int) Fieldslib.Field.t
                    -> t
                    -> int
                    -> 'acc__2)
              -> slots_per_epoch:
                   (   'acc__2
                    -> (t, int) Fieldslib.Field.t
                    -> t
                    -> int
                    -> 'acc__3)
              -> slot_duration:
                   (   'acc__3
                    -> (t, int) Fieldslib.Field.t
                    -> t
                    -> int
                    -> 'acc__4)
              -> epoch_duration:
                   (   'acc__4
                    -> (t, int) Fieldslib.Field.t
                    -> t
                    -> int
                    -> 'acc__5)
              -> genesis_state_timestamp:
                   (   'acc__5
                    -> (t, Block_time.Stable.V1.t) Fieldslib.Field.t
                    -> t
                    -> Block_time.Stable.V1.t
                    -> 'acc__6)
              -> acceptable_network_delay:
                   (   'acc__6
                    -> (t, int) Fieldslib.Field.t
                    -> t
                    -> int
                    -> 'acc__7)
              -> 'acc__7

            val for_all :
                 t
              -> delta:((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> k:((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> slots_per_epoch:
                   ((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> slot_duration:((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> epoch_duration:((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> genesis_state_timestamp:
                   (   (t, Block_time.Stable.V1.t) Fieldslib.Field.t
                    -> t
                    -> Block_time.Stable.V1.t
                    -> bool)
              -> acceptable_network_delay:
                   ((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> bool

            val exists :
                 t
              -> delta:((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> k:((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> slots_per_epoch:
                   ((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> slot_duration:((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> epoch_duration:((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> genesis_state_timestamp:
                   (   (t, Block_time.Stable.V1.t) Fieldslib.Field.t
                    -> t
                    -> Block_time.Stable.V1.t
                    -> bool)
              -> acceptable_network_delay:
                   ((t, int) Fieldslib.Field.t -> t -> int -> bool)
              -> bool

            val to_list :
                 t
              -> delta:((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
              -> k:((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
              -> slots_per_epoch:
                   ((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
              -> slot_duration:
                   ((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
              -> epoch_duration:
                   ((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
              -> genesis_state_timestamp:
                   (   (t, Block_time.Stable.V1.t) Fieldslib.Field.t
                    -> t
                    -> Block_time.Stable.V1.t
                    -> 'elem__)
              -> acceptable_network_delay:
                   ((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
              -> 'elem__ list

            val map :
                 t
              -> delta:((t, int) Fieldslib.Field.t -> t -> int -> int)
              -> k:((t, int) Fieldslib.Field.t -> t -> int -> int)
              -> slots_per_epoch:((t, int) Fieldslib.Field.t -> t -> int -> int)
              -> slot_duration:((t, int) Fieldslib.Field.t -> t -> int -> int)
              -> epoch_duration:((t, int) Fieldslib.Field.t -> t -> int -> int)
              -> genesis_state_timestamp:
                   (   (t, Block_time.Stable.V1.t) Fieldslib.Field.t
                    -> t
                    -> Block_time.Stable.V1.t
                    -> Block_time.Stable.V1.t)
              -> acceptable_network_delay:
                   ((t, int) Fieldslib.Field.t -> t -> int -> int)
              -> t

            val set_all_mutable_fields : t -> unit
          end
        end
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
        array

      val bin_read_to_latest_opt :
           Core_kernel.Bin_prot.Common.buf
        -> pos_ref:int Core_kernel.ref
        -> V1.t option
    end

    type t = Stable.V1.t =
      { delta : int
      ; k : int
      ; slots_per_epoch : int
      ; slot_duration : int
      ; epoch_duration : int
      ; genesis_state_timestamp : Block_time.t
      ; acceptable_network_delay : int
      }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val acceptable_network_delay : t -> int

    val genesis_state_timestamp : t -> Block_time.t

    val epoch_duration : t -> int

    val slot_duration : t -> int

    val slots_per_epoch : t -> int

    val k : t -> int

    val delta : t -> int

    module Fields : sig
      val names : string list

      val acceptable_network_delay : (t, int) Fieldslib.Field.t

      val genesis_state_timestamp : (t, Block_time.t) Fieldslib.Field.t

      val epoch_duration : (t, int) Fieldslib.Field.t

      val slot_duration : (t, int) Fieldslib.Field.t

      val slots_per_epoch : (t, int) Fieldslib.Field.t

      val k : (t, int) Fieldslib.Field.t

      val delta : (t, int) Fieldslib.Field.t

      val fold :
           init:'acc__0
        -> delta:('acc__0 -> (t, int) Fieldslib.Field.t -> 'acc__1)
        -> k:('acc__1 -> (t, int) Fieldslib.Field.t -> 'acc__2)
        -> slots_per_epoch:('acc__2 -> (t, int) Fieldslib.Field.t -> 'acc__3)
        -> slot_duration:('acc__3 -> (t, int) Fieldslib.Field.t -> 'acc__4)
        -> epoch_duration:('acc__4 -> (t, int) Fieldslib.Field.t -> 'acc__5)
        -> genesis_state_timestamp:
             ('acc__5 -> (t, Block_time.t) Fieldslib.Field.t -> 'acc__6)
        -> acceptable_network_delay:
             ('acc__6 -> (t, int) Fieldslib.Field.t -> 'acc__7)
        -> 'acc__7

      val make_creator :
           delta:
             (   (t, int) Fieldslib.Field.t
              -> 'acc__0
              -> ('input__ -> int) * 'acc__1)
        -> k:
             (   (t, int) Fieldslib.Field.t
              -> 'acc__1
              -> ('input__ -> int) * 'acc__2)
        -> slots_per_epoch:
             (   (t, int) Fieldslib.Field.t
              -> 'acc__2
              -> ('input__ -> int) * 'acc__3)
        -> slot_duration:
             (   (t, int) Fieldslib.Field.t
              -> 'acc__3
              -> ('input__ -> int) * 'acc__4)
        -> epoch_duration:
             (   (t, int) Fieldslib.Field.t
              -> 'acc__4
              -> ('input__ -> int) * 'acc__5)
        -> genesis_state_timestamp:
             (   (t, Block_time.t) Fieldslib.Field.t
              -> 'acc__5
              -> ('input__ -> Block_time.t) * 'acc__6)
        -> acceptable_network_delay:
             (   (t, int) Fieldslib.Field.t
              -> 'acc__6
              -> ('input__ -> int) * 'acc__7)
        -> 'acc__0
        -> ('input__ -> t) * 'acc__7

      val create :
           delta:int
        -> k:int
        -> slots_per_epoch:int
        -> slot_duration:int
        -> epoch_duration:int
        -> genesis_state_timestamp:Block_time.t
        -> acceptable_network_delay:int
        -> t

      val map :
           delta:((t, int) Fieldslib.Field.t -> int)
        -> k:((t, int) Fieldslib.Field.t -> int)
        -> slots_per_epoch:((t, int) Fieldslib.Field.t -> int)
        -> slot_duration:((t, int) Fieldslib.Field.t -> int)
        -> epoch_duration:((t, int) Fieldslib.Field.t -> int)
        -> genesis_state_timestamp:
             ((t, Block_time.t) Fieldslib.Field.t -> Block_time.t)
        -> acceptable_network_delay:((t, int) Fieldslib.Field.t -> int)
        -> t

      val iter :
           delta:((t, int) Fieldslib.Field.t -> unit)
        -> k:((t, int) Fieldslib.Field.t -> unit)
        -> slots_per_epoch:((t, int) Fieldslib.Field.t -> unit)
        -> slot_duration:((t, int) Fieldslib.Field.t -> unit)
        -> epoch_duration:((t, int) Fieldslib.Field.t -> unit)
        -> genesis_state_timestamp:((t, Block_time.t) Fieldslib.Field.t -> unit)
        -> acceptable_network_delay:((t, int) Fieldslib.Field.t -> unit)
        -> unit

      val for_all :
           delta:((t, int) Fieldslib.Field.t -> bool)
        -> k:((t, int) Fieldslib.Field.t -> bool)
        -> slots_per_epoch:((t, int) Fieldslib.Field.t -> bool)
        -> slot_duration:((t, int) Fieldslib.Field.t -> bool)
        -> epoch_duration:((t, int) Fieldslib.Field.t -> bool)
        -> genesis_state_timestamp:((t, Block_time.t) Fieldslib.Field.t -> bool)
        -> acceptable_network_delay:((t, int) Fieldslib.Field.t -> bool)
        -> bool

      val exists :
           delta:((t, int) Fieldslib.Field.t -> bool)
        -> k:((t, int) Fieldslib.Field.t -> bool)
        -> slots_per_epoch:((t, int) Fieldslib.Field.t -> bool)
        -> slot_duration:((t, int) Fieldslib.Field.t -> bool)
        -> epoch_duration:((t, int) Fieldslib.Field.t -> bool)
        -> genesis_state_timestamp:((t, Block_time.t) Fieldslib.Field.t -> bool)
        -> acceptable_network_delay:((t, int) Fieldslib.Field.t -> bool)
        -> bool

      val to_list :
           delta:((t, int) Fieldslib.Field.t -> 'elem__)
        -> k:((t, int) Fieldslib.Field.t -> 'elem__)
        -> slots_per_epoch:((t, int) Fieldslib.Field.t -> 'elem__)
        -> slot_duration:((t, int) Fieldslib.Field.t -> 'elem__)
        -> epoch_duration:((t, int) Fieldslib.Field.t -> 'elem__)
        -> genesis_state_timestamp:
             ((t, Block_time.t) Fieldslib.Field.t -> 'elem__)
        -> acceptable_network_delay:((t, int) Fieldslib.Field.t -> 'elem__)
        -> 'elem__ list

      val map_poly :
        ([< `Read | `Set_and_create ], t, 'x0) Fieldslib.Field.user -> 'x0 list

      module Direct : sig
        val iter :
             t
          -> delta:((t, int) Fieldslib.Field.t -> t -> int -> unit)
          -> k:((t, int) Fieldslib.Field.t -> t -> int -> unit)
          -> slots_per_epoch:((t, int) Fieldslib.Field.t -> t -> int -> unit)
          -> slot_duration:((t, int) Fieldslib.Field.t -> t -> int -> unit)
          -> epoch_duration:((t, int) Fieldslib.Field.t -> t -> int -> unit)
          -> genesis_state_timestamp:
               (   (t, Block_time.t) Fieldslib.Field.t
                -> t
                -> Block_time.t
                -> unit)
          -> acceptable_network_delay:
               ((t, int) Fieldslib.Field.t -> t -> int -> unit)
          -> unit

        val fold :
             t
          -> init:'acc__0
          -> delta:
               ('acc__0 -> (t, int) Fieldslib.Field.t -> t -> int -> 'acc__1)
          -> k:('acc__1 -> (t, int) Fieldslib.Field.t -> t -> int -> 'acc__2)
          -> slots_per_epoch:
               ('acc__2 -> (t, int) Fieldslib.Field.t -> t -> int -> 'acc__3)
          -> slot_duration:
               ('acc__3 -> (t, int) Fieldslib.Field.t -> t -> int -> 'acc__4)
          -> epoch_duration:
               ('acc__4 -> (t, int) Fieldslib.Field.t -> t -> int -> 'acc__5)
          -> genesis_state_timestamp:
               (   'acc__5
                -> (t, Block_time.t) Fieldslib.Field.t
                -> t
                -> Block_time.t
                -> 'acc__6)
          -> acceptable_network_delay:
               ('acc__6 -> (t, int) Fieldslib.Field.t -> t -> int -> 'acc__7)
          -> 'acc__7

        val for_all :
             t
          -> delta:((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> k:((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> slots_per_epoch:((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> slot_duration:((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> epoch_duration:((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> genesis_state_timestamp:
               (   (t, Block_time.t) Fieldslib.Field.t
                -> t
                -> Block_time.t
                -> bool)
          -> acceptable_network_delay:
               ((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> bool

        val exists :
             t
          -> delta:((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> k:((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> slots_per_epoch:((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> slot_duration:((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> epoch_duration:((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> genesis_state_timestamp:
               (   (t, Block_time.t) Fieldslib.Field.t
                -> t
                -> Block_time.t
                -> bool)
          -> acceptable_network_delay:
               ((t, int) Fieldslib.Field.t -> t -> int -> bool)
          -> bool

        val to_list :
             t
          -> delta:((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
          -> k:((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
          -> slots_per_epoch:((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
          -> slot_duration:((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
          -> epoch_duration:((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
          -> genesis_state_timestamp:
               (   (t, Block_time.t) Fieldslib.Field.t
                -> t
                -> Block_time.t
                -> 'elem__)
          -> acceptable_network_delay:
               ((t, int) Fieldslib.Field.t -> t -> int -> 'elem__)
          -> 'elem__ list

        val map :
             t
          -> delta:((t, int) Fieldslib.Field.t -> t -> int -> int)
          -> k:((t, int) Fieldslib.Field.t -> t -> int -> int)
          -> slots_per_epoch:((t, int) Fieldslib.Field.t -> t -> int -> int)
          -> slot_duration:((t, int) Fieldslib.Field.t -> t -> int -> int)
          -> epoch_duration:((t, int) Fieldslib.Field.t -> t -> int -> int)
          -> genesis_state_timestamp:
               (   (t, Block_time.t) Fieldslib.Field.t
                -> t
                -> Block_time.t
                -> Block_time.t)
          -> acceptable_network_delay:
               ((t, int) Fieldslib.Field.t -> t -> int -> int)
          -> t

        val set_all_mutable_fields : t -> unit
      end
    end

    val t :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> protocol_constants:Genesis_constants.Protocol.t
      -> t
  end

  module Genesis_epoch_data : sig
    module Data : sig
      type t =
        { ledger : Mina_base.Ledger.t Core_kernel.Lazy.t
        ; seed : Mina_base.Epoch_seed.t
        }
    end

    type tt = { staking : Data.t; next : Data.t option }

    type t = tt option

    val for_unit_tests : t

    val compiled : t
  end

  module Data : sig
    module Local_state : sig
      module Snapshot : sig
        module Ledger_snapshot : sig
          type t =
            | Genesis_epoch_ledger of Mina_base.Ledger.t
            | Ledger_db of Mina_base.Ledger.Db.t

          val close : t -> unit

          val merkle_root : t -> Mina_base.Ledger_hash.t
        end
      end

      type t

      val to_yojson : t -> Yojson.Safe.t

      val create :
           Signature_lib.Public_key.Compressed.Set.t
        -> genesis_ledger:Mina_base.Ledger.t Core_kernel.Lazy.t
        -> genesis_epoch_data:Genesis_epoch_data.t
        -> epoch_ledger_location:string
        -> ledger_depth:int
        -> genesis_state_hash:Mina_base.State_hash.t
        -> t

      val current_block_production_keys :
        t -> Signature_lib.Public_key.Compressed.Set.t

      val current_epoch_delegatee_table :
           local_state:t
        -> Mina_base.Account.t Mina_base.Account.Index.Table.t
           Signature_lib.Public_key.Compressed.Table.t

      val last_epoch_delegatee_table :
           local_state:t
        -> Mina_base.Account.t Mina_base.Account.Index.Table.t
           Signature_lib.Public_key.Compressed.Table.t
           option

      val next_epoch_ledger : t -> Snapshot.Ledger_snapshot.t

      val staking_epoch_ledger : t -> Snapshot.Ledger_snapshot.t

      val block_production_keys_swap :
           constants:Constants.t
        -> t
        -> Signature_lib.Public_key.Compressed.Set.t
        -> Block_time.t
        -> unit
    end

    module Vrf : sig
      val check :
           constraint_constants:Genesis_constants.Constraint_constants.t
        -> global_slot:Mina_numbers.Global_slot.t
        -> seed:Mina_base.Epoch_seed.t
        -> producer_private_key:Signature_lib.Private_key.t
        -> producer_public_key:Signature_lib.Public_key.Compressed.t
        -> total_stake:Currency.Amount.t
        -> logger:Logger.t
        -> get_delegators:
             (   Signature_lib.Public_key.Compressed.t
              -> Mina_base.Account.t Mina_base.Account.Index.Table.t option)
        -> ( ( [ `Vrf_eval of string ]
             * [> `Vrf_output of Consensus_vrf.Output_hash.t ]
             * [> `Delegator of
                  Signature_lib.Public_key.Compressed.t
                  * Mina_base.Account.Index.t ] )
             option
           , unit )
           Interruptible.t
    end

    module Prover_state : sig
      module Stable : sig
        module V1 : sig
          type t

          val bin_size_t : t Bin_prot.Size.sizer

          val bin_write_t : t Bin_prot.Write.writer

          val bin_read_t : t Bin_prot.Read.reader

          val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

          val bin_shape_t : Bin_prot.Shape.t

          val bin_writer_t : t Bin_prot.Type_class.writer

          val bin_reader_t : t Bin_prot.Type_class.reader

          val bin_t : t Bin_prot.Type_class.t

          val __versioned__ : unit
        end

        module Latest = V1

        val versions :
          ( int
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
          array

        val bin_read_to_latest_opt :
             Core_kernel.Bin_prot.Common.buf
          -> pos_ref:int Core_kernel.ref
          -> V1.t option
      end

      type t = Stable.V1.t

      val to_yojson : t -> Yojson.Safe.t

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      val genesis_data :
        genesis_epoch_ledger:Mina_base.Ledger.t Core_kernel.Lazy.t -> t

      val precomputed_handler :
           constraint_constants:Genesis_constants.Constraint_constants.t
        -> genesis_epoch_ledger:Mina_base.Ledger.t Core_kernel.Lazy.t
        -> Snark_params.Tick.Handler.t

      val handler :
           t
        -> constraint_constants:Genesis_constants.Constraint_constants.t
        -> pending_coinbase:Mina_base.Pending_coinbase_witness.t
        -> Snark_params.Tick.Handler.t

      val ledger_depth : t -> int
    end

    module Consensus_transition : sig
      module Value : sig
        module Stable : sig
          module V1 : sig
            type t

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
            ( int
            * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t)
            )
            array

          val bin_read_to_latest_opt :
               Core_kernel.Bin_prot.Common.buf
            -> pos_ref:int Core_kernel.ref
            -> V1.t option
        end

        type t = Stable.V1.t

        val to_yojson : t -> Yojson.Safe.t

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t
      end

      type var

      val typ : (var, Value.t) Crypto_params.Tick.Typ.t

      val genesis : Value.t
    end

    module Consensus_time : sig
      module Stable : sig
        module V1 : sig
          type t

          val to_yojson : t -> Yojson.Safe.t

          val of_yojson :
            Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

          val bin_size_t : t Bin_prot.Size.sizer

          val bin_write_t : t Bin_prot.Write.writer

          val bin_read_t : t Bin_prot.Read.reader

          val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

          val bin_shape_t : Bin_prot.Shape.t

          val bin_writer_t : t Bin_prot.Type_class.writer

          val bin_reader_t : t Bin_prot.Type_class.reader

          val bin_t : t Bin_prot.Type_class.t

          val __versioned__ : unit

          val compare : t -> t -> int

          val t_of_sexp : Sexplib0.Sexp.t -> t

          val sexp_of_t : t -> Sexplib0.Sexp.t
        end

        module Latest = V1

        val versions :
          ( int
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
          array

        val bin_read_to_latest_opt :
             Core_kernel.Bin_prot.Common.buf
          -> pos_ref:int Core_kernel.ref
          -> V1.t option
      end

      type t = Stable.V1.t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val compare : t -> t -> int

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      val to_string_hum : t -> string

      val to_time : constants:Constants.t -> t -> Block_time.t

      val of_time_exn : constants:Constants.t -> Block_time.t -> t

      val get_old : constants:Constants.t -> t -> t

      val to_uint32 : t -> Unsigned.UInt32.t

      val epoch : t -> Unsigned.UInt32.t

      val slot : t -> Unsigned.UInt32.t

      val succ : t -> t

      val start_time : constants:Constants.t -> t -> Block_time.t

      val end_time : constants:Constants.t -> t -> Block_time.t

      val to_global_slot : t -> Mina_numbers.Global_slot.t

      val of_global_slot :
        constants:Constants.t -> Mina_numbers.Global_slot.t -> t

      val zero : constants:Constants.t -> t
    end

    module Consensus_state : sig
      module Value : sig
        module Stable : sig
          module V1 : sig
            type t

            val to_yojson : t -> Yojson.Safe.t

            val of_yojson :
              Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

            val bin_size_t : t Bin_prot.Size.sizer

            val bin_write_t : t Bin_prot.Write.writer

            val bin_read_t : t Bin_prot.Read.reader

            val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

            val bin_shape_t : Bin_prot.Shape.t

            val bin_writer_t : t Bin_prot.Type_class.writer

            val bin_reader_t : t Bin_prot.Type_class.reader

            val bin_t : t Bin_prot.Type_class.t

            val __versioned__ : unit

            val hash_fold_t :
              Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

            val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

            val equal : t -> t -> bool

            val compare : t -> t -> int

            val t_of_sexp : Sexplib0.Sexp.t -> t

            val sexp_of_t : t -> Sexplib0.Sexp.t
          end

          module Latest = V1

          val versions :
            ( int
            * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t)
            )
            array

          val bin_read_to_latest_opt :
               Core_kernel.Bin_prot.Common.buf
            -> pos_ref:int Core_kernel.ref
            -> V1.t option
        end

        type t = Stable.V1.t

        val to_yojson : t -> Yojson.Safe.t

        val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

        val hash_fold_t :
          Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

        val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

        val equal : t -> t -> bool

        val compare : t -> t -> int

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t

        module For_tests : sig
          val with_global_slot_since_genesis :
            t -> Mina_numbers.Global_slot.t -> t
        end
      end

      type display

      val display_to_yojson : display -> Yojson.Safe.t

      val display_of_yojson :
        Yojson.Safe.t -> display Ppx_deriving_yojson_runtime.error_or

      type var

      val typ :
           constraint_constants:Genesis_constants.Constraint_constants.t
        -> (var, Value.t) Snark_params.Tick.Typ.t

      val negative_one :
           genesis_ledger:Mina_base.Ledger.t Core_kernel.Lazy.t
        -> genesis_epoch_data:Genesis_epoch_data.t
        -> constants:Constants.t
        -> constraint_constants:Genesis_constants.Constraint_constants.t
        -> Value.t

      val create_genesis_from_transition :
           negative_one_protocol_state_hash:Mina_base.State_hash.t
        -> consensus_transition:Consensus_transition.Value.t
        -> genesis_ledger:Mina_base.Ledger.t Core_kernel.Lazy.t
        -> genesis_epoch_data:Genesis_epoch_data.t
        -> constraint_constants:Genesis_constants.Constraint_constants.t
        -> constants:Constants.t
        -> Value.t

      val create_genesis :
           negative_one_protocol_state_hash:Mina_base.State_hash.t
        -> genesis_ledger:Mina_base.Ledger.t Core_kernel.Lazy.t
        -> genesis_epoch_data:Genesis_epoch_data.t
        -> constraint_constants:Genesis_constants.Constraint_constants.t
        -> constants:Constants.t
        -> Value.t

      val var_to_input :
           var
        -> ( ( Snark_params.Tick.Field.Var.t
             , Snark_params.Tick.Boolean.var )
             Random_oracle.Input.t
           , 'a )
           Snark_params.Tick.Checked.t

      val to_input :
        Value.t -> (Snark_params.Tick.Field.t, bool) Random_oracle.Input.t

      val display : Value.t -> display

      val consensus_time : Value.t -> Consensus_time.t

      val blockchain_length : Value.t -> Mina_numbers.Length.t

      val min_window_density : Value.t -> Mina_numbers.Length.t

      val block_stake_winner : Value.t -> Signature_lib.Public_key.Compressed.t

      val block_creator : Value.t -> Signature_lib.Public_key.Compressed.t

      val coinbase_receiver : Value.t -> Signature_lib.Public_key.Compressed.t

      val coinbase_receiver_var : var -> Signature_lib.Public_key.Compressed.var

      val curr_global_slot_var : var -> Mina_numbers.Global_slot.Checked.t

      val blockchain_length_var : var -> Mina_numbers.Length.Checked.t

      val min_window_density_var : var -> Mina_numbers.Length.Checked.t

      val total_currency_var : var -> Currency.Amount.Checked.t

      val staking_epoch_data_var : var -> Mina_base.Epoch_data.var

      val staking_epoch_data : Value.t -> Mina_base.Epoch_data.Value.t

      val next_epoch_data_var : var -> Mina_base.Epoch_data.var

      val next_epoch_data : Value.t -> Mina_base.Epoch_data.Value.t

      val graphql_type : unit -> ('ctx, Value.t option) Graphql_async.Schema.typ

      val curr_slot : Value.t -> Slot.t

      val epoch_count : Value.t -> Mina_numbers.Length.t

      val curr_global_slot : Value.t -> Mina_numbers.Global_slot.t

      val global_slot_since_genesis : Value.t -> Mina_numbers.Global_slot.t

      val global_slot_since_genesis_var :
        var -> Mina_numbers.Global_slot.Checked.t

      val is_genesis_state : Value.t -> bool

      val is_genesis_state_var :
        var -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

      val supercharge_coinbase_var : var -> Snark_params.Tick.Boolean.var

      val supercharge_coinbase : Value.t -> bool
    end

    module Block_data : sig
      type t

      val epoch_ledger : t -> Mina_base.Sparse_ledger.t

      val global_slot : t -> Mina_numbers.Global_slot.t

      val prover_state : t -> Prover_state.t

      val global_slot_since_genesis : t -> Mina_numbers.Global_slot.t

      val coinbase_receiver : t -> Signature_lib.Public_key.Compressed.t
    end

    module Epoch_data_for_vrf : sig
      module Stable : sig
        module V1 : sig
          type t =
            { epoch_ledger : Mina_base.Epoch_ledger.Value.Stable.V1.t
            ; epoch_seed : Mina_base.Epoch_seed.Stable.V1.t
            ; epoch : Mina_numbers.Length.Stable.V1.t
            ; global_slot : Mina_numbers.Global_slot.Stable.V1.t
            ; global_slot_since_genesis : Mina_numbers.Global_slot.Stable.V1.t
            ; delegatee_table :
                Mina_base.Account.Stable.V1.t
                Mina_base.Account.Index.Stable.V1.Table.t
                Signature_lib.Public_key.Compressed.Stable.V1.Table.t
            }

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
        end

        module Latest = V1

        val versions :
          ( int
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
          array

        val bin_read_to_latest_opt :
             Core_kernel.Bin_prot.Common.buf
          -> pos_ref:int Core_kernel.ref
          -> V1.t option
      end

      type t = Stable.V1.t =
        { epoch_ledger : Mina_base.Epoch_ledger.Value.t
        ; epoch_seed : Mina_base.Epoch_seed.t
        ; epoch : Mina_numbers.Length.t
        ; global_slot : Mina_numbers.Global_slot.t
        ; global_slot_since_genesis : Mina_numbers.Global_slot.t
        ; delegatee_table :
            Mina_base.Account.t Mina_base.Account.Index.Stable.V1.Table.t
            Signature_lib.Public_key.Compressed.Stable.V1.Table.t
        }

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Slot_won : sig
      module Stable : sig
        module V1 : sig
          type t =
            { delegator :
                Signature_lib.Public_key.Compressed.Stable.V1.t
                * Mina_base.Account.Index.Stable.V1.t
            ; producer : Signature_lib.Keypair.Stable.V1.t
            ; global_slot : Mina_numbers.Global_slot.Stable.V1.t
            ; global_slot_since_genesis : Mina_numbers.Global_slot.Stable.V1.t
            ; vrf_result : Consensus_vrf.Output_hash.Stable.V1.t
            }

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
        end

        module Latest = V1

        val versions :
          ( int
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
          array

        val bin_read_to_latest_opt :
             Core_kernel.Bin_prot.Common.buf
          -> pos_ref:int Core_kernel.ref
          -> V1.t option
      end

      type t = Stable.V1.t =
        { delegator :
            Signature_lib.Public_key.Compressed.t * Mina_base.Account.Index.t
        ; producer : Signature_lib.Keypair.t
        ; global_slot : Mina_numbers.Global_slot.t
        ; global_slot_since_genesis : Mina_numbers.Global_slot.t
        ; vrf_result : Consensus_vrf.Output_hash.t
        }

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end
  end

  module Coinbase_receiver : sig
    type t = [ `Other of Signature_lib.Public_key.Compressed.t | `Producer ]

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
  end

  module Hooks : sig
    module Rpcs : sig
      type ('query, 'response) rpc

      type rpc_handler =
        | Rpc_handler :
            { rpc : ('q, 'r) rpc
            ; f : ('q, 'r) Mina_base.Rpc_intf.rpc_fn
            ; cost : 'q -> int
            ; budget : int * [ `Per of Core.Time.Span.t ]
            }
            -> rpc_handler

      val implementation_of_rpc :
        ('q, 'r) rpc -> ('q, 'r) Mina_base.Rpc_intf.rpc_implementation

      val match_handler :
           rpc_handler
        -> ('q, 'r) rpc
        -> do_:(('q, 'r) Mina_base.Rpc_intf.rpc_fn -> 'a)
        -> 'a option

      val rpc_handlers :
           logger:Logger.t
        -> local_state:Data.Local_state.t
        -> genesis_ledger_hash:Mina_base.Frozen_ledger_hash.t
        -> rpc_handler list

      type query =
        { query :
            'q 'r.    Network_peer.Peer.t -> ('q, 'r) rpc -> 'q
            -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t
        }
    end

    val is_genesis_epoch : constants:Constants.t -> Block_time.t -> bool

    val received_at_valid_time :
         constants:Constants.t
      -> Data.Consensus_state.Value.t
      -> time_received:Unix_timestamp.t
      -> (unit, [ `Too_early | `Too_late of int64 ]) Core_kernel.result

    type select_status = [ `Keep | `Take ]

    val equal_select_status : select_status -> select_status -> bool

    val select :
         constants:Constants.t
      -> existing:
           Data.Consensus_state.Value.t Mina_base.State_hash.With_state_hashes.t
      -> candidate:
           Data.Consensus_state.Value.t Mina_base.State_hash.With_state_hashes.t
      -> logger:Logger.t
      -> select_status

    val get_epoch_data_for_vrf :
         constants:Constants.t
      -> Unix_timestamp.t
      -> Data.Consensus_state.Value.t
      -> local_state:Data.Local_state.t
      -> logger:Logger.t
      -> Data.Epoch_data_for_vrf.t * Data.Local_state.Snapshot.Ledger_snapshot.t

    val get_block_data :
         slot_won:Data.Slot_won.t
      -> ledger_snapshot:Data.Local_state.Snapshot.Ledger_snapshot.t
      -> coinbase_receiver:Coinbase_receiver.t
      -> Data.Block_data.t

    val frontier_root_transition :
         Data.Consensus_state.Value.t
      -> Data.Consensus_state.Value.t
      -> local_state:Data.Local_state.t
      -> snarked_ledger:Mina_base.Ledger.Db.t
      -> genesis_ledger_hash:Mina_base.Frozen_ledger_hash.t
      -> unit

    val should_bootstrap :
         constants:Constants.t
      -> existing:
           Data.Consensus_state.Value.t Mina_base.State_hash.With_state_hashes.t
      -> candidate:
           Data.Consensus_state.Value.t Mina_base.State_hash.With_state_hashes.t
      -> logger:Logger.t
      -> bool

    val get_epoch_ledger :
         constants:Constants.t
      -> consensus_state:Data.Consensus_state.Value.t
      -> local_state:Data.Local_state.t
      -> Data.Local_state.Snapshot.Ledger_snapshot.t

    val epoch_end_time :
      constants:Constants.t -> Mina_numbers.Length.t -> Block_time.t

    type local_state_sync

    val local_state_sync_to_yojson : local_state_sync -> Yojson.Safe.t

    val required_local_state_sync :
         constants:Constants.t
      -> consensus_state:Data.Consensus_state.Value.t
      -> local_state:Data.Local_state.t
      -> local_state_sync option

    val sync_local_state :
         logger:Logger.t
      -> trust_system:Trust_system.t
      -> local_state:Data.Local_state.t
      -> random_peers:(int -> Network_peer.Peer.t list Async.Deferred.t)
      -> query_peer:Rpcs.query
      -> ledger_depth:int
      -> local_state_sync
      -> unit Async.Deferred.Or_error.t

    module Make_state_hooks : functor
      (Blockchain_state : sig
         module Poly : sig
           module Stable : sig
             module V1 : sig
               type ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t

               val bin_shape_t :
                    Core_kernel.Bin_prot.Shape.t
                 -> Core_kernel.Bin_prot.Shape.t
                 -> Core_kernel.Bin_prot.Shape.t
                 -> Core_kernel.Bin_prot.Shape.t
                 -> Core_kernel.Bin_prot.Shape.t

               val bin_size_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Size.sizer
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Size.sizer
                 -> 'token_id Core_kernel.Bin_prot.Size.sizer
                 -> 'time Core_kernel.Bin_prot.Size.sizer
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Size.sizer

               val bin_write_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Write.writer
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Write.writer
                 -> 'token_id Core_kernel.Bin_prot.Write.writer
                 -> 'time Core_kernel.Bin_prot.Write.writer
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Write.writer

               val bin_writer_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Type_class.writer
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Type_class.writer
                 -> 'token_id Core_kernel.Bin_prot.Type_class.writer
                 -> 'time Core_kernel.Bin_prot.Type_class.writer
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Type_class.writer

               val bin_read_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Read.reader
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Read.reader
                 -> 'token_id Core_kernel.Bin_prot.Read.reader
                 -> 'time Core_kernel.Bin_prot.Read.reader
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Read.reader

               val __bin_read_t__ :
                    'staged_ledger_hash Core_kernel.Bin_prot.Read.reader
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Read.reader
                 -> 'token_id Core_kernel.Bin_prot.Read.reader
                 -> 'time Core_kernel.Bin_prot.Read.reader
                 -> (   int
                     -> ( 'staged_ledger_hash
                        , 'snarked_ledger_hash
                        , 'token_id
                        , 'time )
                        t)
                    Core_kernel.Bin_prot.Read.reader

               val bin_reader_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Type_class.reader
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Type_class.reader
                 -> 'token_id Core_kernel.Bin_prot.Type_class.reader
                 -> 'time Core_kernel.Bin_prot.Type_class.reader
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Type_class.reader

               val bin_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Type_class.t
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Type_class.t
                 -> 'token_id Core_kernel.Bin_prot.Type_class.t
                 -> 'time Core_kernel.Bin_prot.Type_class.t
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Type_class.t

               val __versioned__ : unit

               val sexp_of_t :
                    ('staged_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
                 -> ('snarked_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
                 -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
                 -> ('time -> Ppx_sexp_conv_lib.Sexp.t)
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                 -> Ppx_sexp_conv_lib.Sexp.t

               val t_of_sexp :
                    (Ppx_sexp_conv_lib.Sexp.t -> 'staged_ledger_hash)
                 -> (Ppx_sexp_conv_lib.Sexp.t -> 'snarked_ledger_hash)
                 -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
                 -> (Ppx_sexp_conv_lib.Sexp.t -> 'time)
                 -> Ppx_sexp_conv_lib.Sexp.t
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
             end

             module Latest : sig
               type ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t =
                 ( 'staged_ledger_hash
                 , 'snarked_ledger_hash
                 , 'token_id
                 , 'time )
                 V1.t

               val bin_shape_t :
                    Core_kernel.Bin_prot.Shape.t
                 -> Core_kernel.Bin_prot.Shape.t
                 -> Core_kernel.Bin_prot.Shape.t
                 -> Core_kernel.Bin_prot.Shape.t
                 -> Core_kernel.Bin_prot.Shape.t

               val bin_size_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Size.sizer
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Size.sizer
                 -> 'token_id Core_kernel.Bin_prot.Size.sizer
                 -> 'time Core_kernel.Bin_prot.Size.sizer
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Size.sizer

               val bin_write_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Write.writer
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Write.writer
                 -> 'token_id Core_kernel.Bin_prot.Write.writer
                 -> 'time Core_kernel.Bin_prot.Write.writer
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Write.writer

               val bin_writer_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Type_class.writer
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Type_class.writer
                 -> 'token_id Core_kernel.Bin_prot.Type_class.writer
                 -> 'time Core_kernel.Bin_prot.Type_class.writer
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Type_class.writer

               val bin_read_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Read.reader
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Read.reader
                 -> 'token_id Core_kernel.Bin_prot.Read.reader
                 -> 'time Core_kernel.Bin_prot.Read.reader
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Read.reader

               val __bin_read_t__ :
                    'staged_ledger_hash Core_kernel.Bin_prot.Read.reader
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Read.reader
                 -> 'token_id Core_kernel.Bin_prot.Read.reader
                 -> 'time Core_kernel.Bin_prot.Read.reader
                 -> (   int
                     -> ( 'staged_ledger_hash
                        , 'snarked_ledger_hash
                        , 'token_id
                        , 'time )
                        t)
                    Core_kernel.Bin_prot.Read.reader

               val bin_reader_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Type_class.reader
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Type_class.reader
                 -> 'token_id Core_kernel.Bin_prot.Type_class.reader
                 -> 'time Core_kernel.Bin_prot.Type_class.reader
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Type_class.reader

               val bin_t :
                    'staged_ledger_hash Core_kernel.Bin_prot.Type_class.t
                 -> 'snarked_ledger_hash Core_kernel.Bin_prot.Type_class.t
                 -> 'token_id Core_kernel.Bin_prot.Type_class.t
                 -> 'time Core_kernel.Bin_prot.Type_class.t
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                    Core_kernel.Bin_prot.Type_class.t

               val __versioned__ : unit

               val sexp_of_t :
                    ('staged_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
                 -> ('snarked_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
                 -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
                 -> ('time -> Ppx_sexp_conv_lib.Sexp.t)
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
                 -> Ppx_sexp_conv_lib.Sexp.t

               val t_of_sexp :
                    (Ppx_sexp_conv_lib.Sexp.t -> 'staged_ledger_hash)
                 -> (Ppx_sexp_conv_lib.Sexp.t -> 'snarked_ledger_hash)
                 -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
                 -> (Ppx_sexp_conv_lib.Sexp.t -> 'time)
                 -> Ppx_sexp_conv_lib.Sexp.t
                 -> ( 'staged_ledger_hash
                    , 'snarked_ledger_hash
                    , 'token_id
                    , 'time )
                    t
             end
           end

           type ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t =
             ( 'staged_ledger_hash
             , 'snarked_ledger_hash
             , 'token_id
             , 'time )
             Stable.V1.t

           val sexp_of_t :
                ('staged_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
             -> ('snarked_ledger_hash -> Ppx_sexp_conv_lib.Sexp.t)
             -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
             -> ('time -> Ppx_sexp_conv_lib.Sexp.t)
             -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
             -> Ppx_sexp_conv_lib.Sexp.t

           val t_of_sexp :
                (Ppx_sexp_conv_lib.Sexp.t -> 'staged_ledger_hash)
             -> (Ppx_sexp_conv_lib.Sexp.t -> 'snarked_ledger_hash)
             -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
             -> (Ppx_sexp_conv_lib.Sexp.t -> 'time)
             -> Ppx_sexp_conv_lib.Sexp.t
             -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t
         end

         module Value : sig
           module Stable : sig
             module V1 : sig
               type t =
                 ( Mina_base.Staged_ledger_hash.t
                 , Mina_base.Frozen_ledger_hash.t
                 , Mina_base.Token_id.t
                 , Block_time.t )
                 Poly.t

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

             module Latest : sig
               type t =
                 ( Mina_base.Staged_ledger_hash.t
                 , Mina_base.Frozen_ledger_hash.t
                 , Mina_base.Token_id.t
                 , Block_time.t )
                 Poly.t

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

             val versions :
               ( int
               * (   Core_kernel.Bigstring.t
                  -> pos_ref:int Core_kernel.ref
                  -> Latest.t) )
               array

             val bin_read_to_latest_opt :
                  Core_kernel.Bin_prot.Common.buf
               -> pos_ref:int Core_kernel.ref
               -> Latest.t option
           end

           type t = Stable.Latest.t

           val t_of_sexp : Sexplib0.Sexp.t -> t

           val sexp_of_t : t -> Sexplib0.Sexp.t
         end

         type var =
           ( Mina_base.Staged_ledger_hash.var
           , Mina_base.Frozen_ledger_hash.var
           , Mina_base.Token_id.var
           , Block_time.Unpacked.var )
           Poly.t

         val create_value :
              staged_ledger_hash:Mina_base.Staged_ledger_hash.t
           -> snarked_ledger_hash:Mina_base.Frozen_ledger_hash.t
           -> genesis_ledger_hash:Mina_base.Frozen_ledger_hash.t
           -> snarked_next_available_token:Mina_base.Token_id.t
           -> timestamp:Block_time.t
           -> Value.t

         val staged_ledger_hash :
           ('staged_ledger_hash, 'a, 'b, 'c) Poly.t -> 'staged_ledger_hash

         val snarked_ledger_hash :
           ('a, 'frozen_ledger_hash, 'b, 'c) Poly.t -> 'frozen_ledger_hash

         val genesis_ledger_hash :
           ('a, 'frozen_ledger_hash, 'b, 'c) Poly.t -> 'frozen_ledger_hash

         val snarked_next_available_token :
           ('a, 'b, 'token_id, 'c) Poly.t -> 'token_id

         val timestamp : ('a, 'b, 'c, 'time) Poly.t -> 'time
       end)
      (Protocol_state : sig
         module Poly : sig
           module Stable : sig
             module V1 : sig
               type ('state_hash, 'body) t

               val to_yojson :
                    ('state_hash -> Yojson.Safe.t)
                 -> ('body -> Yojson.Safe.t)
                 -> ('state_hash, 'body) t
                 -> Yojson.Safe.t

               val bin_shape_t :
                 Bin_prot.Shape.t -> Bin_prot.Shape.t -> Bin_prot.Shape.t

               val bin_size_t : ('a, 'b, ('a, 'b) t) Bin_prot.Size.sizer2

               val bin_write_t : ('a, 'b, ('a, 'b) t) Bin_prot.Write.writer2

               val bin_read_t : ('a, 'b, ('a, 'b) t) Bin_prot.Read.reader2

               val __bin_read_t__ :
                 ('a, 'b, int -> ('a, 'b) t) Bin_prot.Read.reader2

               val bin_writer_t :
                 ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.writer

               val bin_reader_t :
                 ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.reader

               val bin_t : ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.t

               val __versioned__ : unit

               val equal :
                    ('state_hash -> 'state_hash -> bool)
                 -> ('body -> 'body -> bool)
                 -> ('state_hash, 'body) t
                 -> ('state_hash, 'body) t
                 -> bool

               val hash_fold_t :
                    (   Ppx_hash_lib.Std.Hash.state
                     -> 'state_hash
                     -> Ppx_hash_lib.Std.Hash.state)
                 -> (   Ppx_hash_lib.Std.Hash.state
                     -> 'body
                     -> Ppx_hash_lib.Std.Hash.state)
                 -> Ppx_hash_lib.Std.Hash.state
                 -> ('state_hash, 'body) t
                 -> Ppx_hash_lib.Std.Hash.state

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

             module Latest : sig
               type ('state_hash, 'body) t = ('state_hash, 'body) V1.t

               val to_yojson :
                    ('state_hash -> Yojson.Safe.t)
                 -> ('body -> Yojson.Safe.t)
                 -> ('state_hash, 'body) t
                 -> Yojson.Safe.t

               val bin_shape_t :
                 Bin_prot.Shape.t -> Bin_prot.Shape.t -> Bin_prot.Shape.t

               val bin_size_t : ('a, 'b, ('a, 'b) t) Bin_prot.Size.sizer2

               val bin_write_t : ('a, 'b, ('a, 'b) t) Bin_prot.Write.writer2

               val bin_read_t : ('a, 'b, ('a, 'b) t) Bin_prot.Read.reader2

               val __bin_read_t__ :
                 ('a, 'b, int -> ('a, 'b) t) Bin_prot.Read.reader2

               val bin_writer_t :
                 ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.writer

               val bin_reader_t :
                 ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.reader

               val bin_t : ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.t

               val __versioned__ : unit

               val equal :
                    ('state_hash -> 'state_hash -> bool)
                 -> ('body -> 'body -> bool)
                 -> ('state_hash, 'body) t
                 -> ('state_hash, 'body) t
                 -> bool

               val hash_fold_t :
                    (   Ppx_hash_lib.Std.Hash.state
                     -> 'state_hash
                     -> Ppx_hash_lib.Std.Hash.state)
                 -> (   Ppx_hash_lib.Std.Hash.state
                     -> 'body
                     -> Ppx_hash_lib.Std.Hash.state)
                 -> Ppx_hash_lib.Std.Hash.state
                 -> ('state_hash, 'body) t
                 -> Ppx_hash_lib.Std.Hash.state

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
           end

           type ('state_hash, 'body) t = ('state_hash, 'body) Stable.V1.t

           val to_yojson :
                ('state_hash -> Yojson.Safe.t)
             -> ('body -> Yojson.Safe.t)
             -> ('state_hash, 'body) t
             -> Yojson.Safe.t

           val equal :
                ('state_hash -> 'state_hash -> bool)
             -> ('body -> 'body -> bool)
             -> ('state_hash, 'body) t
             -> ('state_hash, 'body) t
             -> bool

           val hash_fold_t :
                (   Ppx_hash_lib.Std.Hash.state
                 -> 'state_hash
                 -> Ppx_hash_lib.Std.Hash.state)
             -> (   Ppx_hash_lib.Std.Hash.state
                 -> 'body
                 -> Ppx_hash_lib.Std.Hash.state)
             -> Ppx_hash_lib.Std.Hash.state
             -> ('state_hash, 'body) t
             -> Ppx_hash_lib.Std.Hash.state

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

         module Body : sig
           module Poly : sig
             module Stable : sig
               module V1 : sig
                 type ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t

                 val bin_shape_t :
                      Core_kernel.Bin_prot.Shape.t
                   -> Core_kernel.Bin_prot.Shape.t
                   -> Core_kernel.Bin_prot.Shape.t
                   -> Core_kernel.Bin_prot.Shape.t
                   -> Core_kernel.Bin_prot.Shape.t

                 val bin_size_t :
                      'state_hash Core_kernel.Bin_prot.Size.sizer
                   -> 'blockchain_state Core_kernel.Bin_prot.Size.sizer
                   -> 'consensus_state Core_kernel.Bin_prot.Size.sizer
                   -> 'constants Core_kernel.Bin_prot.Size.sizer
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Size.sizer

                 val bin_write_t :
                      'state_hash Core_kernel.Bin_prot.Write.writer
                   -> 'blockchain_state Core_kernel.Bin_prot.Write.writer
                   -> 'consensus_state Core_kernel.Bin_prot.Write.writer
                   -> 'constants Core_kernel.Bin_prot.Write.writer
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Write.writer

                 val bin_writer_t :
                      'state_hash Core_kernel.Bin_prot.Type_class.writer
                   -> 'blockchain_state Core_kernel.Bin_prot.Type_class.writer
                   -> 'consensus_state Core_kernel.Bin_prot.Type_class.writer
                   -> 'constants Core_kernel.Bin_prot.Type_class.writer
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Type_class.writer

                 val bin_read_t :
                      'state_hash Core_kernel.Bin_prot.Read.reader
                   -> 'blockchain_state Core_kernel.Bin_prot.Read.reader
                   -> 'consensus_state Core_kernel.Bin_prot.Read.reader
                   -> 'constants Core_kernel.Bin_prot.Read.reader
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Read.reader

                 val __bin_read_t__ :
                      'state_hash Core_kernel.Bin_prot.Read.reader
                   -> 'blockchain_state Core_kernel.Bin_prot.Read.reader
                   -> 'consensus_state Core_kernel.Bin_prot.Read.reader
                   -> 'constants Core_kernel.Bin_prot.Read.reader
                   -> (   int
                       -> ( 'state_hash
                          , 'blockchain_state
                          , 'consensus_state
                          , 'constants )
                          t)
                      Core_kernel.Bin_prot.Read.reader

                 val bin_reader_t :
                      'state_hash Core_kernel.Bin_prot.Type_class.reader
                   -> 'blockchain_state Core_kernel.Bin_prot.Type_class.reader
                   -> 'consensus_state Core_kernel.Bin_prot.Type_class.reader
                   -> 'constants Core_kernel.Bin_prot.Type_class.reader
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Type_class.reader

                 val bin_t :
                      'state_hash Core_kernel.Bin_prot.Type_class.t
                   -> 'blockchain_state Core_kernel.Bin_prot.Type_class.t
                   -> 'consensus_state Core_kernel.Bin_prot.Type_class.t
                   -> 'constants Core_kernel.Bin_prot.Type_class.t
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Type_class.t

                 val __versioned__ : unit

                 val sexp_of_t :
                      ('state_hash -> Ppx_sexp_conv_lib.Sexp.t)
                   -> ('blockchain_state -> Ppx_sexp_conv_lib.Sexp.t)
                   -> ('consensus_state -> Ppx_sexp_conv_lib.Sexp.t)
                   -> ('constants -> Ppx_sexp_conv_lib.Sexp.t)
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                   -> Ppx_sexp_conv_lib.Sexp.t

                 val t_of_sexp :
                      (Ppx_sexp_conv_lib.Sexp.t -> 'state_hash)
                   -> (Ppx_sexp_conv_lib.Sexp.t -> 'blockchain_state)
                   -> (Ppx_sexp_conv_lib.Sexp.t -> 'consensus_state)
                   -> (Ppx_sexp_conv_lib.Sexp.t -> 'constants)
                   -> Ppx_sexp_conv_lib.Sexp.t
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
               end

               module Latest : sig
                 type ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t =
                   ( 'state_hash
                   , 'blockchain_state
                   , 'consensus_state
                   , 'constants )
                   V1.t

                 val bin_shape_t :
                      Core_kernel.Bin_prot.Shape.t
                   -> Core_kernel.Bin_prot.Shape.t
                   -> Core_kernel.Bin_prot.Shape.t
                   -> Core_kernel.Bin_prot.Shape.t
                   -> Core_kernel.Bin_prot.Shape.t

                 val bin_size_t :
                      'state_hash Core_kernel.Bin_prot.Size.sizer
                   -> 'blockchain_state Core_kernel.Bin_prot.Size.sizer
                   -> 'consensus_state Core_kernel.Bin_prot.Size.sizer
                   -> 'constants Core_kernel.Bin_prot.Size.sizer
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Size.sizer

                 val bin_write_t :
                      'state_hash Core_kernel.Bin_prot.Write.writer
                   -> 'blockchain_state Core_kernel.Bin_prot.Write.writer
                   -> 'consensus_state Core_kernel.Bin_prot.Write.writer
                   -> 'constants Core_kernel.Bin_prot.Write.writer
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Write.writer

                 val bin_writer_t :
                      'state_hash Core_kernel.Bin_prot.Type_class.writer
                   -> 'blockchain_state Core_kernel.Bin_prot.Type_class.writer
                   -> 'consensus_state Core_kernel.Bin_prot.Type_class.writer
                   -> 'constants Core_kernel.Bin_prot.Type_class.writer
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Type_class.writer

                 val bin_read_t :
                      'state_hash Core_kernel.Bin_prot.Read.reader
                   -> 'blockchain_state Core_kernel.Bin_prot.Read.reader
                   -> 'consensus_state Core_kernel.Bin_prot.Read.reader
                   -> 'constants Core_kernel.Bin_prot.Read.reader
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Read.reader

                 val __bin_read_t__ :
                      'state_hash Core_kernel.Bin_prot.Read.reader
                   -> 'blockchain_state Core_kernel.Bin_prot.Read.reader
                   -> 'consensus_state Core_kernel.Bin_prot.Read.reader
                   -> 'constants Core_kernel.Bin_prot.Read.reader
                   -> (   int
                       -> ( 'state_hash
                          , 'blockchain_state
                          , 'consensus_state
                          , 'constants )
                          t)
                      Core_kernel.Bin_prot.Read.reader

                 val bin_reader_t :
                      'state_hash Core_kernel.Bin_prot.Type_class.reader
                   -> 'blockchain_state Core_kernel.Bin_prot.Type_class.reader
                   -> 'consensus_state Core_kernel.Bin_prot.Type_class.reader
                   -> 'constants Core_kernel.Bin_prot.Type_class.reader
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Type_class.reader

                 val bin_t :
                      'state_hash Core_kernel.Bin_prot.Type_class.t
                   -> 'blockchain_state Core_kernel.Bin_prot.Type_class.t
                   -> 'consensus_state Core_kernel.Bin_prot.Type_class.t
                   -> 'constants Core_kernel.Bin_prot.Type_class.t
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                      Core_kernel.Bin_prot.Type_class.t

                 val __versioned__ : unit

                 val sexp_of_t :
                      ('state_hash -> Ppx_sexp_conv_lib.Sexp.t)
                   -> ('blockchain_state -> Ppx_sexp_conv_lib.Sexp.t)
                   -> ('consensus_state -> Ppx_sexp_conv_lib.Sexp.t)
                   -> ('constants -> Ppx_sexp_conv_lib.Sexp.t)
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
                   -> Ppx_sexp_conv_lib.Sexp.t

                 val t_of_sexp :
                      (Ppx_sexp_conv_lib.Sexp.t -> 'state_hash)
                   -> (Ppx_sexp_conv_lib.Sexp.t -> 'blockchain_state)
                   -> (Ppx_sexp_conv_lib.Sexp.t -> 'consensus_state)
                   -> (Ppx_sexp_conv_lib.Sexp.t -> 'constants)
                   -> Ppx_sexp_conv_lib.Sexp.t
                   -> ( 'state_hash
                      , 'blockchain_state
                      , 'consensus_state
                      , 'constants )
                      t
               end
             end

             type ( 'state_hash
                  , 'blockchain_state
                  , 'consensus_state
                  , 'constants )
                  t =
               ( 'state_hash
               , 'blockchain_state
               , 'consensus_state
               , 'constants )
               Stable.V1.t

             val sexp_of_t :
                  ('state_hash -> Ppx_sexp_conv_lib.Sexp.t)
               -> ('blockchain_state -> Ppx_sexp_conv_lib.Sexp.t)
               -> ('consensus_state -> Ppx_sexp_conv_lib.Sexp.t)
               -> ('constants -> Ppx_sexp_conv_lib.Sexp.t)
               -> ( 'state_hash
                  , 'blockchain_state
                  , 'consensus_state
                  , 'constants )
                  t
               -> Ppx_sexp_conv_lib.Sexp.t

             val t_of_sexp :
                  (Ppx_sexp_conv_lib.Sexp.t -> 'state_hash)
               -> (Ppx_sexp_conv_lib.Sexp.t -> 'blockchain_state)
               -> (Ppx_sexp_conv_lib.Sexp.t -> 'consensus_state)
               -> (Ppx_sexp_conv_lib.Sexp.t -> 'constants)
               -> Ppx_sexp_conv_lib.Sexp.t
               -> ( 'state_hash
                  , 'blockchain_state
                  , 'consensus_state
                  , 'constants )
                  t
           end

           module Value : sig
             module Stable : sig
               module V1 : sig
                 type t =
                   ( Mina_base.State_hash.t
                   , Blockchain_state.Value.t
                   , Data.Consensus_state.Value.t
                   , Mina_base.Protocol_constants_checked.Value.Stable.V1.t )
                   Poly.t

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

               module Latest : sig
                 type t =
                   ( Mina_base.State_hash.t
                   , Blockchain_state.Value.t
                   , Data.Consensus_state.Value.t
                   , Mina_base.Protocol_constants_checked.Value.Stable.V1.t )
                   Poly.t

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

               val versions :
                 ( int
                 * (   Core_kernel.Bigstring.t
                    -> pos_ref:int Core_kernel.ref
                    -> Latest.t) )
                 array

               val bin_read_to_latest_opt :
                    Core_kernel.Bin_prot.Common.buf
                 -> pos_ref:int Core_kernel.ref
                 -> Latest.t option
             end

             type t = Stable.Latest.t

             val to_yojson : t -> Yojson.Safe.t

             val t_of_sexp : Sexplib0.Sexp.t -> t

             val sexp_of_t : t -> Sexplib0.Sexp.t
           end

           type var =
             ( Mina_base.State_hash.var
             , Blockchain_state.var
             , Data.Consensus_state.var
             , Mina_base.Protocol_constants_checked.var )
             Poly.t
         end

         module Value : sig
           module Stable : sig
             module V1 : sig
               type t = (Mina_base.State_hash.t, Body.Value.Stable.V1.t) Poly.t

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

               val equal : t -> t -> bool

               val compare : t -> t -> int
             end

             module Latest : sig
               type t = (Mina_base.State_hash.t, Body.Value.Stable.V1.t) Poly.t

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

               val equal : t -> t -> bool

               val compare : t -> t -> int
             end

             val versions :
               ( int
               * (   Core_kernel.Bigstring.t
                  -> pos_ref:int Core_kernel.ref
                  -> Latest.t) )
               array

             val bin_read_to_latest_opt :
                  Core_kernel.Bin_prot.Common.buf
               -> pos_ref:int Core_kernel.ref
               -> Latest.t option
           end

           type t = Stable.Latest.t

           val t_of_sexp : Sexplib0.Sexp.t -> t

           val sexp_of_t : t -> Sexplib0.Sexp.t

           val equal : t -> t -> bool

           val compare : t -> t -> int
         end

         type var = (Mina_base.State_hash.var, Body.var) Poly.t

         val create_value :
              previous_state_hash:Mina_base.State_hash.t
           -> genesis_state_hash:Mina_base.State_hash.t
           -> blockchain_state:Blockchain_state.Value.t
           -> consensus_state:Data.Consensus_state.Value.t
           -> constants:Mina_base.Protocol_constants_checked.Value.t
           -> Value.t

         val previous_state_hash : ('state_hash, 'a) Poly.t -> 'state_hash

         val body : ('a, 'body) Poly.t -> 'body

         val blockchain_state :
              ('a, ('b, 'blockchain_state, 'c, 'd) Body.Poly.t) Poly.t
           -> 'blockchain_state

         val genesis_state_hash :
              ?state_hash:Mina_base.State_hash.t option
           -> Value.t
           -> Mina_base.State_hash.t

         val consensus_state :
              ('a, ('b, 'c, 'consensus_state, 'd) Body.Poly.t) Poly.t
           -> 'consensus_state

         val constants :
           ('a, ('b, 'c, 'd, 'constants) Body.Poly.t) Poly.t -> 'constants

         val hash : Value.t -> Mina_base.State_hash.t
       end)
      (Snark_transition : sig
         module Poly : sig
           type ( 'blockchain_state
                , 'consensus_transition
                , 'pending_coinbase_update )
                t

           val t_of_sexp :
                (Sexplib0.Sexp.t -> 'a)
             -> (Sexplib0.Sexp.t -> 'b)
             -> (Sexplib0.Sexp.t -> 'c)
             -> Sexplib0.Sexp.t
             -> ('a, 'b, 'c) t

           val sexp_of_t :
                ('a -> Sexplib0.Sexp.t)
             -> ('b -> Sexplib0.Sexp.t)
             -> ('c -> Sexplib0.Sexp.t)
             -> ('a, 'b, 'c) t
             -> Sexplib0.Sexp.t
         end

         module Value : sig
           type t

           val t_of_sexp : Sexplib0.Sexp.t -> t

           val sexp_of_t : t -> Sexplib0.Sexp.t
         end

         type var =
           ( Blockchain_state.var
           , Data.Consensus_transition.var
           , Mina_base.Pending_coinbase.Update.var )
           Poly.t

         val consensus_transition :
           ('a, 'consensus_transition, 'b) Poly.t -> 'consensus_transition

         val blockchain_state :
           ('blockchain_state, 'a, 'b) Poly.t -> 'blockchain_state
       end)
      -> sig
      val generate_transition :
           previous_protocol_state:Protocol_state.Value.t
        -> blockchain_state:Blockchain_state.Value.t
        -> current_time:Unix_timestamp.t
        -> block_data:Data.Block_data.t
        -> supercharge_coinbase:bool
        -> snarked_ledger_hash:Mina_base.Frozen_ledger_hash.t
        -> genesis_ledger_hash:Mina_base.Frozen_ledger_hash.t
        -> supply_increase:Currency.Amount.t
        -> logger:Logger.t
        -> constraint_constants:Genesis_constants.Constraint_constants.t
        -> Protocol_state.Value.t * Data.Consensus_transition.Value.t

      val next_state_checked :
           constraint_constants:Genesis_constants.Constraint_constants.t
        -> prev_state:Protocol_state.var
        -> prev_state_hash:Mina_base.State_hash.var
        -> Snark_transition.var
        -> Currency.Amount.var
        -> ( [ `Success of Snark_params.Tick.Boolean.var ]
             * Data.Consensus_state.var
           , 'a )
           Snark_params.Tick.Checked.t

      val genesis_winner :
        Signature_lib.Public_key.Compressed.t * Signature_lib.Private_key.t

      module For_tests : sig
        val gen_consensus_state :
             constraint_constants:Genesis_constants.Constraint_constants.t
          -> constants:Constants.t
          -> gen_slot_advancement:int Async.Quickcheck.Generator.t
          -> (   previous_protocol_state:
                   Protocol_state.Value.t
                   Mina_base.State_hash.With_state_hashes.t
              -> snarked_ledger_hash:Mina_base.Frozen_ledger_hash.t
              -> coinbase_receiver:Signature_lib.Public_key.Compressed.t
              -> supercharge_coinbase:bool
              -> Data.Consensus_state.Value.t)
             Async.Quickcheck.Generator.t
      end
    end
  end
end
