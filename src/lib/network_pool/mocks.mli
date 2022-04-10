val trust_system : Trust_system.t

module Transaction_snark_work = Transaction_snark_work

module Base_ledger : sig
  type t = Mina_base.Account.t Mina_base.Account_id.Map.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  module Location : sig
    type t = Mina_base.Account_id.t
  end

  val location_of_account : 'a -> 'b -> 'b option

  val location_of_account_batch : 'a -> 'b list -> ('b * 'b option) list

  val get :
    ('a, 'b, 'c) Core_kernel.Map.t -> 'a -> 'b Core_kernel__.Import.option

  val get_batch :
       ('a, 'b, 'c) Core_kernel.Map.t
    -> 'a list
    -> ('a * 'b Core_kernel__.Import.option) list

  val detached_signal : 'a -> 'b Async_kernel.Deferred.t
end

module Staged_ledger : sig
  type t = Base_ledger.t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val ledger : 'a -> 'a
end

module Transition_frontier : sig
  type table = int Transaction_snark_work.Statement.Table.t

  val table_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> table

  val sexp_of_table : table -> Ppx_sexp_conv_lib.Sexp.t

  type diff = Extensions.Snark_pool_refcount.view

  val diff_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> diff

  val sexp_of_diff : diff -> Ppx_sexp_conv_lib.Sexp.t

  type best_tip_diff = unit

  module Breadcrumb : sig
    type t = Staged_ledger.t

    val staged_ledger : 'a -> 'a
  end

  type t =
    { refcount_table : table
    ; best_tip_table : Transaction_snark_work.Statement.Hash_set.t
    ; mutable ledger : Staged_ledger.t
    ; diff_writer : diff Pipe_lib.Broadcast_pipe.Writer.t
    ; diff_reader : diff Pipe_lib.Broadcast_pipe.Reader.t
    }

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val add_statements :
       int Transaction_snark_work.Statement.Table.t
    -> Transaction_snark_work.Statement.Table.key list
    -> best_tip_diff

  val create : 'a -> t

  val best_tip : t -> Staged_ledger.t

  module Extensions : sig
    module Work = Transaction_snark_work.Statement
  end

  val snark_pool_refcount_pipe : t -> diff Pipe_lib.Broadcast_pipe.Reader.t

  val best_tip_diff_pipe : 'a -> best_tip_diff Pipe_lib.Broadcast_pipe.Reader.t

  val refer_statements :
       t
    -> Transaction_snark_work.Statement.Table.key list
    -> best_tip_diff Async_kernel__Deferred.t

  val remove_from_best_tip :
       t
    -> Transaction_snark_work.Statement.Hash_set.elt list
    -> best_tip_diff Async_kernel__Deferred.t
end
