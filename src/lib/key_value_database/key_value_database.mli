module Monad : sig
  module type S = sig
    type 'a t

    val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

    module Monad_infix : sig
      val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

      val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t
    end

    val bind : 'a t -> f:('a -> 'b t) -> 'b t

    val return : 'a -> 'a t

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val join : 'a t t -> 'a t

    val ignore_m : 'a t -> unit t

    val all : 'a t list -> 'a list t

    val all_unit : unit t list -> unit t

    module Let_syntax : sig
      val return : 'a -> 'a t

      val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

      val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

      module Let_syntax : sig
        val return : 'a -> 'a t

        val bind : 'a t -> f:('a -> 'b t) -> 'b t

        val map : 'a t -> f:('a -> 'b) -> 'b t

        val both : 'a t -> 'b t -> ('a * 'b) t

        module Open_on_rhs : sig end
      end
    end

    module Result : sig
      val lift : 'value t -> ('value, 'err) Core_kernel.Result.t t

      type nonrec ('value, 'err) t = ('value, 'err) Core_kernel.Result.t t

      val ( >>= ) : ('a, 'e) t -> ('a -> ('b, 'e) t) -> ('b, 'e) t

      val ( >>| ) : ('a, 'e) t -> ('a -> 'b) -> ('b, 'e) t

      module Let_syntax : sig
        val return : 'a -> ('a, 'b) t

        val ( >>= ) : ('a, 'e) t -> ('a -> ('b, 'e) t) -> ('b, 'e) t

        val ( >>| ) : ('a, 'e) t -> ('a -> 'b) -> ('b, 'e) t

        module Let_syntax : sig
          val return : 'a -> ('a, 'b) t

          val bind : ('a, 'e) t -> f:('a -> ('b, 'e) t) -> ('b, 'e) t

          val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t

          val both : ('a, 'e) t -> ('b, 'e) t -> ('a * 'b, 'e) t

          module Open_on_rhs : sig end
        end
      end

      module Monad_infix : sig
        val ( >>= ) : ('a, 'e) t -> ('a -> ('b, 'e) t) -> ('b, 'e) t

        val ( >>| ) : ('a, 'e) t -> ('a -> 'b) -> ('b, 'e) t
      end

      val bind : ('a, 'e) t -> f:('a -> ('b, 'e) t) -> ('b, 'e) t

      val return : 'a -> ('a, 'b) t

      val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t

      val join : (('a, 'e) t, 'e) t -> ('a, 'e) t

      val ignore_m : ('a, 'e) t -> (unit, 'e) t

      val all : ('a, 'e) t list -> ('a list, 'e) t

      val all_unit : (unit, 'e) t list -> (unit, 'e) t
    end

    module Option : sig
      type nonrec 'a t = 'a option t

      val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

      val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

      module Monad_infix : sig
        val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

        val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t
      end

      val bind : 'a t -> f:('a -> 'b t) -> 'b t

      val return : 'a -> 'a t

      val map : 'a t -> f:('a -> 'b) -> 'b t

      val join : 'a t t -> 'a t

      val ignore_m : 'a t -> unit t

      val all : 'a t list -> 'a list t

      val all_unit : unit t list -> unit t

      module Let_syntax : sig
        val return : 'a -> 'a t

        val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

        val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

        module Let_syntax : sig
          val return : 'a -> 'a t

          val bind : 'a t -> f:('a -> 'b t) -> 'b t

          val map : 'a t -> f:('a -> 'b) -> 'b t

          val both : 'a t -> 'b t -> ('a * 'b) t

          module Open_on_rhs : sig end
        end
      end
    end
  end

  module Ident : sig
    type 'a t = 'a

    val ( >>= ) : 'a -> ('a -> 'b) -> 'b

    val ( >>| ) : 'a -> ('a -> 'b) -> 'b

    module Monad_infix = Base__Monad.Ident.Monad_infix

    val bind : 'a -> f:('a -> 'b) -> 'b

    val return : 'a -> 'a

    val map : 'a -> f:('a -> 'b) -> 'b

    val join : 'a -> 'a

    val ignore_m : 'a -> unit

    val all : 'a list -> 'a list

    val all_unit : unit list -> unit

    module Let_syntax = Base__Monad.Ident.Let_syntax

    module Result : sig
      val lift : 'a -> ('a, 'b) Core_kernel.Result.t

      type ('a, 'b) t = ('a, 'b) Base.Result.t = Ok of 'a | Error of 'b

      val bin_shape_t : Bin_prot.Shape.t -> Bin_prot.Shape.t -> Bin_prot.Shape.t

      val bin_size_t : ('a, 'b, ('a, 'b) t) Bin_prot.Size.sizer2

      val bin_write_t : ('a, 'b, ('a, 'b) t) Bin_prot.Write.writer2

      val bin_read_t : ('a, 'b, ('a, 'b) t) Bin_prot.Read.reader2

      val __bin_read_t__ : ('a, 'b, int -> ('a, 'b) t) Bin_prot.Read.reader2

      val bin_writer_t : ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.writer

      val bin_reader_t : ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.reader

      val bin_t : ('a, 'b, ('a, 'b) t) Bin_prot.Type_class.S2.t

      val t_of_sexp :
           (Base__.Sexp.t -> 'a)
        -> (Base__.Sexp.t -> 'b)
        -> Base__.Sexp.t
        -> ('a, 'b) t

      val sexp_of_t :
           ('a -> Base__.Sexp.t)
        -> ('b -> Base__.Sexp.t)
        -> ('a, 'b) t
        -> Base__.Sexp.t

      val compare :
           ('ok -> 'ok -> int)
        -> ('err -> 'err -> int)
        -> ('ok, 'err) t
        -> ('ok, 'err) t
        -> int

      val equal :
           ('ok -> 'ok -> bool)
        -> ('err -> 'err -> bool)
        -> ('ok, 'err) t
        -> ('ok, 'err) t
        -> bool

      val hash_fold_t :
           (   Base__.Ppx_hash_lib.Std.Hash.state
            -> 'ok
            -> Base__.Ppx_hash_lib.Std.Hash.state)
        -> (   Base__.Ppx_hash_lib.Std.Hash.state
            -> 'err
            -> Base__.Ppx_hash_lib.Std.Hash.state)
        -> Base__.Ppx_hash_lib.Std.Hash.state
        -> ('ok, 'err) t
        -> Base__.Ppx_hash_lib.Std.Hash.state

      val ( >>= ) : ('a, 'e) t -> ('a -> ('b, 'e) t) -> ('b, 'e) t

      val ( >>| ) : ('a, 'e) t -> ('a -> 'b) -> ('b, 'e) t

      module Let_syntax = Core_kernel__Result.Let_syntax
      module Monad_infix = Core_kernel__Result.Monad_infix

      val bind : ('a, 'e) t -> f:('a -> ('b, 'e) t) -> ('b, 'e) t

      val return : 'a -> ('a, 'b) t

      val join : (('a, 'e) t, 'e) t -> ('a, 'e) t

      val ignore_m : ('a, 'e) t -> (unit, 'e) t

      val all : ('a, 'e) t list -> ('a list, 'e) t

      val all_unit : (unit, 'e) t list -> (unit, 'e) t

      (*val ignore : ('a, 'err) t -> (unit, 'err) t*)

      val fail : 'err -> ('a, 'err) t

      val failf : ('a, unit, string, ('b, string) t) format4 -> 'a

      val is_ok : ('a, 'b) t -> bool

      val is_error : ('a, 'b) t -> bool

      val ok : ('ok, 'a) t -> 'ok option

      val ok_exn : ('ok, exn) t -> 'ok

      val ok_or_failwith : ('ok, string) t -> 'ok

      val error : ('a, 'err) t -> 'err option

      val of_option : 'ok option -> error:'err -> ('ok, 'err) t

      val iter : ('ok, 'a) t -> f:('ok -> unit) -> unit

      val iter_error : ('a, 'err) t -> f:('err -> unit) -> unit

      val map : ('ok, 'err) t -> f:('ok -> 'c) -> ('c, 'err) t

      val map_error : ('ok, 'err) t -> f:('err -> 'c) -> ('ok, 'c) t

      val combine :
           ('ok1, 'err) t
        -> ('ok2, 'err) t
        -> ok:('ok1 -> 'ok2 -> 'ok3)
        -> err:('err -> 'err -> 'err)
        -> ('ok3, 'err) t

      val combine_errors : ('ok, 'err) t list -> ('ok list, 'err list) t

      val combine_errors_unit : (unit, 'err) t list -> (unit, 'err list) t

      val ok_fst : ('ok, 'err) t -> [ `Fst of 'ok | `Snd of 'err ]

      val ok_if_true : bool -> error:'err -> (unit, 'err) t

      val try_with : (unit -> 'a) -> ('a, exn) t

      (*val ok_unit : (unit, 'a) t*)

      module Export = Core_kernel__Result.Export
      module Stable = Core_kernel__Result.Stable
    end

    module Option = Core_kernel.Option
  end
end

module Intf : sig
  module type S = sig
    type t

    type key

    type value

    type config

    module M : Monad.S

    val create : config -> t

    val close : t -> unit

    val get : t -> key:key -> value option M.t

    val get_batch : t -> keys:key list -> value option list M.t

    val set : t -> key:key -> data:value -> unit M.t

    val remove : t -> key:key -> unit M.t

    val set_batch :
      t -> ?remove_keys:key list -> update_pairs:(key * value) list -> unit M.t

    val to_alist : t -> (key * value) list M.t
  end

  module type Ident = sig
    type t

    type key

    type value

    type config

    val create : config -> t

    val close : t -> unit

    val get : t -> key:key -> value option

    val get_batch : t -> keys:key list -> value option list

    val set : t -> key:key -> data:value -> unit

    val remove : t -> key:key -> unit

    val set_batch :
      t -> ?remove_keys:key list -> update_pairs:(key * value) list -> unit

    val to_alist : t -> (key * value) list
  end

  module type Mock = sig
    type t

    type key

    type value

    type config

    val create : config -> t

    val close : t -> unit

    val get : t -> key:key -> value option

    val get_batch : t -> keys:key list -> value option list

    val set : t -> key:key -> data:value -> unit

    val remove : t -> key:key -> unit

    val set_batch :
      t -> ?remove_keys:key list -> update_pairs:(key * value) list -> unit

    val to_alist : t -> (key * value) list

    val random_key : t -> key option

    val to_sexp :
         t
      -> key_sexp:(key -> Core_kernel.Sexp.t)
      -> value_sexp:(value -> Core_kernel.Sexp.t)
      -> Core_kernel.Sexp.t
  end
end

module Make_mock : functor
  (Key : Core_kernel.Hashable.S)
  (Value : sig
     type t
   end)
  -> sig
  type t = Value.t Key.Table.t

  val create : unit -> t

  val close : t -> unit

  val get : t -> key:Key.t -> Value.t option

  val get_batch : t -> keys:Key.t list -> Value.t option list

  val set : t -> key:Key.t -> data:Value.t -> unit

  val remove : t -> key:Key.t -> unit

  val set_batch :
    t -> ?remove_keys:Key.t list -> update_pairs:(Key.t * Value.t) list -> unit

  val to_alist : t -> (Key.t * Value.t) list

  val random_key : t -> Key.t option

  val to_sexp :
       t
    -> key_sexp:(Key.t -> Core_kernel.Sexp.t)
    -> value_sexp:(Value.t -> Core_kernel.Sexp.t)
    -> Core_kernel.Sexp.t
end
