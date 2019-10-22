(** Management of starting, tracking, and killing child processes. *)

open Async
open Pipe_lib

type t

(** A pipe of the standard out of the process, grouped by line. *)
val stdout_lines : t -> string Strict_pipe.Reader.t

(** Same for standard error. *)
val stderr_lines : t -> string Strict_pipe.Reader.t

(** Writer to process's stdin *)
val stdin : t -> Writer.t

val termination_status : t -> Unix.Exit_or_signal.t option

type output_handling =
  [`Log of Logger.Level.t | `Don't_log] * [`Pipe | `No_pipe]

(** Start a process, logging its stdout and stderr at the trace level, and
    handling a lock file. *)
val start_custom :
     logger:Logger.t
  -> name:string
     (** The name of the executable file, without any coda- prefix *)
  -> checkout_relative_path:string
     (** Path to the built executable, relative to the root of a source checkout
     *)
  -> conf_dir:string
     (** Absolute path to the configuration directory for Coda *)
  -> args:string list (** Arguments to the process *)
  -> stdout:output_handling (** What to do with process standard out *)
  -> stderr:output_handling (** What to do with process standard error *)
  -> termination:[ `Always_raise
                 | `Raise_on_failure
                 | `Handler of Unix.Exit_or_signal.t -> unit Deferred.t
                 | `Ignore ]
     (** What to do when the process exits. Not that an exception will never be
         raised and the handler will not be called if you kill the process with
         [kill] *)
  -> t Deferred.Or_error.t

val kill : t -> Unix.Exit_or_signal.t Deferred.Or_error.t

(* TODO *)
(* modify the rpc parallel worker logging code Jiawei wrote to work with this *)
(* val start_rpc_worker *)

module Termination : module type of Termination
