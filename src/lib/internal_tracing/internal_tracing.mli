(** {0 Internal tracing}

    {1 Overview}

    This module implements internal tracing for the Mina node. Traces are composed of
    a list of checkpoints (a tag and a timestamp), and control commands that add
    context information (current block, checkpoint metadata, block metadata, etc).

    The result can be interpreted as a stream of events (composed of checkpoints and
    control commands) that can be processed to reconstruct traces for the processing or
    production of individual blocks.

    {1 Usage}

    Checkpoints are marked by logging to the [internal] log level:

    {[
      [%log internal] "Generate_next_state" ;
      let%bind next_state_opt =
        generate_next_state ~constraint_constants ~scheduled_time
          ~block_data ~previous_protocol_state ~time_controller
          ~staged_ledger:(Breadcrumb.staged_ledger crumb)
          ~transactions ~get_completed_work ~logger ~log_block_creation
          ~winner_pk:winner_pubkey ~block_reward_threshold
      in
      [%log internal] "Generate_next_state_done" ;
    ]}

    The first parameter should be a checkpoint tag (expected format is ["Name_of_checkpoint"]), and
    optionally, metadata can be provided too.

    In addition to checkpoints, control commands are also accepted ["@control_command"]:

    {[
      [%log internal] "@block_metadata"
        ~metadata:
          [ ( "blockchain_length"
            , Mina_numbers.Length.to_yojson
              @@ Mina_block.blockchain_length
              @@ Breadcrumb.block breadcrumb )
          ] ;
    ]}

    {1 Control commands}

    The current list of control commands that can be issued is:

     - ["@metadata"]: associates metadata to the last produced checkpoint
       (this has the same result as including a [metadata] parameter when
       logging a checkpoint).
     - ["@block_metadata"]: associates metadata to the block currently being
       processed/produced.
     - ["@produced_block_state_hash"]: must be issued when the state hash of a
       produced block is known.

    Internally, these control commands are issued too:

     - ["@current_block"]: used to notify of a execution context change that
       brings a different block into context.
     - ["@current_call_id"]: used to notify of a execution context change that
       brings a different concurrent verifier or prover call into context.
     - ["@internal_tracing_enabled"]: issued whenever internal tracing is enabled.
     - ["@internal_tracing_disabled"]: issued whenever internal tracing is disabled.
     - ["@mina_node_metadata"]: associates global metadata about the current node
       (useful for version, branch, etc)
     - ["@rotated_log_end"]: issued when a log file is rotated to notify
       log consumers.
     - ["@rotated_log_started"]: issued when a log file is rotated to notify
       log consumers.

    {1 Output Format}

    The output format is {{: https://jsonlines.org/} JSON Lines}.

    Checkpoints are represented as arrays of two elements, the tag and a timestamp:

    Control commands are represented as JSON objects, with one key and one value.
    The key is the control command name, and the value is the parameter.contents

    {2 Example}

    {[
     {"current_block":"3NKk9rxqKp2fyt9fX4JyTu6yRMDfk3k7Wke2aDZVvQs7ReDazxbZ"}
     ["External_block_received",1677161355.688698]
     {"block_metadata":{"blockchain_length":"2"}}
    ]}

    *)

(** {1 API} *)

(** [is_enabled ()] returns [true] if internal tracing is enabled, and [false] otherwise. *)
val is_enabled : unit -> bool

(** [register_toggle_callback callback] will register [callback] to be called whenever
    internal tracing is toggled.

    This is useful to synchronize internal tracing done by subprocesses like the verifier
    and prover.

    [callback] will be called with [true] if internal tracing must be enabled, and with
    [false] if it must be disabled. It must return a [Deferred.t] that will be resolved
    once the call completes. *)
val register_toggle_callback : (bool -> unit Async_kernel.Deferred.t) -> unit

(** [toggle `Enabled] will enable tracing.
    [toggle `Disabled] will disable tracing.

    If [force] is [false] (the default), and if tracing is already active,
    then trying to enable tracing is a noop.

    The returned promise will be resolved when all the calls to the registered toggle
    callbacks have been resolved. *)
val toggle :
     logger:Logger.t
  -> ?force:bool
  -> [ `Enabled | `Disabled ]
  -> unit Async_kernel.Deferred.t

(** [with_state_hash state_hash f] runs [f] in a context in which checkpoints
    and metadata will be associated to a block with state hash equal to [state_hash].

    Any context in which checkpoints or metadata are recorded must be wrapped
    in either {!val:with_state_hash} or {!val:with_slot} for the checkpoints to be
    properly associated to the block being processed/produced. *)
val with_state_hash : Mina_base.State_hash.t -> (unit -> 'a) -> 'a

(** [with_slot global_slot f] runs [f] in a context in which checkpoints
    and metadata will be associated to a block being produced with global_slot
    equal to [global_slot].

    Any context in which checkpoints or metadata are recorded must be wrapped
    in either {!val:with_state_hash} or {!val:with_slot} for the checkpoints to be
    properly associated to the block being processed/produced. *)
val with_slot : Mina_numbers.Global_slot.t -> (unit -> 'a) -> 'a

module For_logger : sig
  (** Returns a transport that outputs events to a json-lines file which gets rotated after it
      grows past the specified size limit. *)
  val json_lines_rotate_transport :
       directory:string
    -> ?log_filename:string
    -> ?max_size:int
    -> ?num_rotate:int
    -> unit
    -> Logger.Transport.t

  (** Processor for the "internal" log level used to record checkpoints *)
  val processor : Logger.Processor.t
end

module Context_logger : module type of Internal_tracing_context_logger

module Context_call : module type of Internal_tracing_context_call
