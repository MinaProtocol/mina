open Core_kernel
module Make :
  functor (M : Monad.S) -> sig
    module Ring_buffer : sig
      type 'a t [@@deriving sexp, bin_io]
      val read_all : 'a t -> 'a list
    end

    module State : sig
      module Job : sig
        type ('a, 'd) t =
          | Merge_up of 'a option
          | Merge of 'a option * 'a option
          | Base of 'd option
        [@@deriving bin_io, sexp]
      end

      type ('a, 'b, 'd) t [@@deriving bin_io]
      val jobs : ('a, 'b, 'd) t -> ('a, 'd) Job.t Ring_buffer.t
    end

    val scan :
      init:'b ->
      data:'d Linear_pipe.Reader.t ->
      parallelism_log_2:int ->
      map:('d -> 'a M.t) ->
      assoc_op:('a -> 'a -> 'a M.t) ->
      merge:('b -> 'a -> 'b M.t) ->
      sexp_a:('a -> Sexp.t) ->
      sexp_d:('d -> Sexp.t) ->
      eq_b:('b -> 'b -> bool) ->
      ('b option M.t * ('a, 'b, 'd) State.t) Linear_pipe.Reader.t

    val scan_from :
      state:('a, 'b, 'd) State.t ->
      data:'d Linear_pipe.Reader.t ->
      map:('d -> 'a M.t) ->
      assoc_op:('a -> 'a -> 'a M.t) ->
      merge:('b -> 'a -> 'b M.t) ->
      sexp_a:('a -> Sexp.t) ->
      sexp_d:('d -> Sexp.t) ->
      eq_b:('b -> 'b -> bool) ->
      ('b option M.t * ('a, 'b, 'd) State.t) Linear_pipe.Reader.t
  end

