(** Management of starting, tracking, and killing child processes. *)

open Core_kernel
open Async
open Pipe_lib

(** A managed child process *)
type t

exception Child_died

(** A pipe of the standard out of the process. *)
val stdout : t -> string Strict_pipe.Reader.t

(** A pipe of the standard error of the process. *)
val stderr : t -> string Strict_pipe.Reader.t

(** Writer to process's stdin *)
val stdin : t -> Writer.t

val pid : t -> Pid.t

(** [None] if the process is still running, [Some] when it's exited *)
val termination_status : t -> Unix.Exit_or_signal.t Or_error.t option

type output_type = [ `Chunks | `Lines ]

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
  -> stdout:output_type
  -> stderr:output_type
  -> termination:
       [ `Always_raise
       | `Raise_on_failure
       | `Handler of
            killed:bool
         -> Process.t
         -> Unix.Exit_or_signal.t Or_error.t
         -> unit Deferred.t
       | `Ignore ]
       (** What to do when the process exits. Note that an exception will not be
         raised after you run [kill] on it, regardless of this value.
         An [Error _] passed to a [`Handler _] indicates that there was an
         error monitoring the process, and that it is unknown whether the
         process started.
     *)
  -> t Deferred.Or_error.t

val kill : t -> Unix.Exit_or_signal.t Deferred.Or_error.t

(* TODO: Launch RPC parallel workers with this stuff, modify the rpc parallel
   worker logging code Jiawei wrote to work this way. *)
(* val start_rpc_worker : ... *)

module Termination : module type of Termination

val register_process : Termination.t -> t -> Termination.process_kind -> unit
