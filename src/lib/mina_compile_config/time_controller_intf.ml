module type S = sig
  type t [@@deriving sexp, equal, compare]

  val create : t -> t

  val basic : logger:Logger.t -> t

  (** Override the time offset set by the [MINA_TIME_OFFSET] environment
          variable for all block time controllers.
          [enable_setting_offset] must have been called first, and
          [disable_setting_offset] must not have been called, otherwise this
          raises a [Failure].
      *)
  val set_time_offset : Core_kernel.Time.Span.t -> unit

  (** Get the current time offset, either from the [MINA_TIME_OFFSET]
          environment variable, or as last set by [set_time_offset].
      *)
  val get_time_offset : logger:Logger.t -> Core_kernel.Time.Span.t

  (** Disallow setting the time offset. This should be run at every
          entrypoint which does not explicitly need to update the time offset.
      *)
  val disable_setting_offset : unit -> unit

  (** Allow setting the time offset. This may only be run if
          [disable_setting_offset] has not already been called, otherwise it will
          raise a [Failure].
      *)
  val enable_setting_offset : unit -> unit
end
