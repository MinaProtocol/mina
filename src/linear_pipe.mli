open Core_kernel
open Async_kernel
    
module Writer : sig
  type 'a t = 'a Pipe.Writer.t
end

module Reader : sig
  type 'a t =
    { pipe : 'a Pipe.Reader.t
    ; mutable has_reader : bool 
    }
end

val create : unit -> 'a Reader.t * 'a Writer.t

val wrap_reader : 'a Pipe.Reader.t -> 'a Reader.t

val iter
  :  ?consumer          : Pipe.Consumer.t
  -> ?continue_on_error : bool  (** default is [false] *)
  -> 'a Reader.t
  -> f                  : ('a -> unit Deferred.t)
  -> unit Deferred.t

val iter_unordered
  :  ?consumer          : Pipe.Consumer.t
  -> max_concurrency    : int
  -> 'a Reader.t
  -> f                  : ('a -> unit Deferred.t)
  -> unit Deferred.t
                                    
val fold : 'a Reader.t -> init:'accum -> f:('accum -> 'a -> 'accum Deferred.t) -> 'accum Deferred.t

val of_list : 'a List.t -> 'a Reader.t

val map : 'a Reader.t -> f:('a -> 'b) -> 'b Reader.t

val filter_map : 'a Reader.t -> f:('a -> 'b option) -> 'b Reader.t

val transfer : 'a Reader.t -> 'b Writer.t -> f:('a -> 'b ) -> unit Deferred.t

val merge_unordered : 'a Reader.t List.t -> 'a Reader.t

val close_read : 'a Reader.t -> unit

val closed : 'a Reader.t -> unit Deferred.t

val fork : 'a Reader.t -> int -> 'a Reader.t List.t

val fork2 : 'a Reader.t -> 'a Reader.t * 'a Reader.t

val fork3 : 'a Reader.t -> 'a Reader.t * 'a Reader.t * 'a Reader.t

val partition_map2 : 'a Reader.t -> f:('a -> [ `Fst of 'b  | `Snd of 'c ]) -> 'b Reader.t * 'c Reader.t

val partition_map3 : 'a Reader.t -> f:('a -> [ `Fst of 'b  | `Snd of 'c | `Trd of 'd ]) -> 'b Reader.t * 'c Reader.t * 'd Reader.t

val filter_map_unordered 
  : max_concurrency:int
  -> 'a Reader.t 
  -> f:('a -> 'b option Deferred.t) 
  -> 'b Reader.t
