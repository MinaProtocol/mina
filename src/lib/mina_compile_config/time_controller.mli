module T : functor
  (F : sig
     type time

     type span

     val to_span_since_epoch : time -> span

     val of_span_since_epoch : span -> time

     val of_time_span : Core_kernel.Time.Span.t -> span

     val of_time : Core_kernel.Time.t -> time

     val ( + ) : span -> span -> span
   end)
  -> sig
  include Time_controller_intf.S

  val to_system_time : t -> F.time -> F.time

  val now : t -> F.time
end
