(** Running external programs *)

open Import

type accepted_codes =
  | These of int list
  | All

(** How to handle sub-process failures *)
type ('a, 'b) failure_mode =
  | Strict : ('a, 'a) failure_mode
  (** Fail if the process exits with anything else than [0] *)
  | Accept : accepted_codes -> ('a, ('a, int) result) failure_mode
  (** Accept the following non-zero exit codes, and return [Error
      code] if the process exists with one of these codes. *)

(** Where to redirect standard output *)
type std_output_to =
  | Terminal
  | File        of Path.t
  | Opened_file of opened_file

and opened_file =
  { filename : Path.t
  ; desc     : opened_file_desc
  ; tail     : bool
  (** If [true], the descriptor is closed after starting the command *)
  }

and opened_file_desc =
  | Fd      of Unix.file_descr
  | Channel of out_channel

(** Why a Fiber.t was run *)
type purpose =
  | Internal_job
  | Build_job of Path.Set.t

(** [run ?dir ?stdout_to prog args] spawns a sub-process and wait for its termination *)
val run
  :  ?dir:Path.t
  -> ?stdout_to:std_output_to
  -> ?stderr_to:std_output_to
  -> env:Env.t
  -> ?purpose:purpose
  -> (unit, 'a) failure_mode
  -> Path.t
  -> string list
  -> 'a Fiber.t

(** Run a command and capture its output *)
val run_capture
  :  ?dir:Path.t
  -> ?stderr_to:std_output_to
  -> env:Env.t
  -> ?purpose:purpose
  -> (string, 'a) failure_mode
  -> Path.t
  -> string list
  -> 'a Fiber.t
val run_capture_line
  :  ?dir:Path.t
  -> ?stderr_to:std_output_to
  -> env:Env.t
  -> ?purpose:purpose
  -> (string, 'a) failure_mode
  -> Path.t
  -> string list
  -> 'a Fiber.t
val run_capture_lines
  :  ?dir:Path.t
  -> ?stderr_to:std_output_to
  -> env:Env.t
  -> ?purpose:purpose
  -> (string list, 'a) failure_mode
  -> Path.t
  -> string list
  -> 'a Fiber.t

