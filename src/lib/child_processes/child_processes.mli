(** Management of starting, tracking, and killing child processes. *)

open Async
open Pipe_lib

(** A managed child process *)
type t

exception Child_died

(** A pipe of the standard out of the process, grouped by line. *)
val stdout_lines : t -> string Strict_pipe.Reader.t

(** Same for standard error. *)
val stderr_lines : t -> string Strict_pipe.Reader.t

(** Writer to process's stdin *)
val stdin : t -> Writer.t

(** Pid of process *)
val pid : t -> Core.Pid.t

(** [None] if the process is still running, [Some] when it's exited *)
val termination_status : t -> Unix.Exit_or_signal.t option

(** What to do with one of standard out or standard error. If the first
    component is [`Log] and the process outputs valid messages in our JSON
    format they will be passed through unmodified regardless of the level.
    Otherwise they'll be wrapped and logged at the specified level.
    If the second argument is [`Pipe] the lines will be written into the
    appropriate strict pipe, accessible via [stdout_lines] or [stderr_lines].
    Otherwise the pipe will be empty, and reading from it will raise an
    exception.
*)
type output_handling =
  [`Log of Logger.Level.t | `Don't_log]
  * [`Pipe | `No_pipe]
  * [`Keep_empty | `Filter_empty]

(** Start a process, handling a lock file, termination, optional logging, and
    the standard in, out and error fds. This is for "custom" processes, as
    opposed to ones that are built using RPC parallel. *)
val start_custom :
     logger:Logger.t
  -> name:string
     (** The name of the executable file, without any coda- prefix *)
  -> git_root_relative_path:string
     (** Path to the built executable, relative to the root of a source checkout
     *)
  -> conf_dir:string
     (** Absolute path to the configuration directory for Coda *)
  -> args:string list (** Arguments to the process *)
  -> stdout:output_handling (** What to do with process standard out *)
  -> stderr:output_handling (** What to do with process standard error *)
  -> termination:[ `Always_raise
                 | `Raise_on_failure
                 | `Handler of
                   killed:bool -> Unix.Exit_or_signal.t -> unit Deferred.t
                 | `Ignore ]
     (** What to do when the process exits. Note that an exception will not be
         raised after you run [kill] on it, regardless of this value. *)
  -> t Deferred.Or_error.t

val kill : t -> Unix.Exit_or_signal.t Deferred.Or_error.t

(* TODO: Launch RPC parallel workers with this stuff, modify the rpc parallel
   worker logging code Jiawei wrote to work this way. *)
(* val start_rpc_worker : ... *)

module Termination : module type of Termination
