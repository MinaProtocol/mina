(** Every setting the guardian runs on, and where it came from.

    A setting may be given as a command line flag or as an environment
    variable. The flag wins when both are given. The variables are the ones
    the bash guardian used, so a deployment that set them keeps working. *)

open Core

(** Values taken straight off the command line, before any environment
    variable is consulted. [None] means the flag was not given, so the
    environment variable may still supply it. *)
type flags =
  { archive_uri : string option
  ; precomputed_blocks_url : string option
  ; network : string option
  ; block_format : string option
  ; interval : float option
  ; idle_multiplier : int option
  ; http_timeout : float option
  ; retries : int option
  ; retry_delay : float option
  ; max_blocks : int option
  ; min_height : int option
  ; max_consecutive_failures : int option
  ; dry_run : bool
  }

(** Settings resolved and checked. Every value here is usable as it stands:
    spans are positive, counts are not negative, and the block source has been
    parsed. *)
type t =
  { archive_uri : Uri.t
  ; blocks : Block_source.t option
        (** [None] for [audit], which reads no blocks *)
  ; network : string option
  ; format : Ingest.format
  ; interval : Time_ns.Span.t  (** between passes in [daemon] mode *)
  ; idle_multiplier : int
        (** [interval] is multiplied by this after a pass that closed every
            gap, so a healthy archive is polled less often *)
  ; http_timeout : Time_ns.Span.t  (** for one block file *)
  ; retries : int  (** further attempts after the first, per block file *)
  ; retry_delay : Time_ns.Span.t
  ; max_blocks : int option  (** stop a pass after this many blocks *)
  ; min_height : int option
        (** Lowest height this archive is meant to hold. Set it on a
            hard-forked or truncated archive, which has no genesis block to
            find: blocks at or below it are the bottom of the archive rather
            than a missing parent. *)
  ; max_consecutive_failures : int  (** before [daemon] gives up *)
  ; dry_run : bool  (** report what would be fetched, write nothing *)
  }

(** The command line flags, shared by every subcommand. *)
val param : flags Command.Param.t

(** Resolve [flags] against the environment.

    [requires_blocks] is [false] for [audit], which reads no blocks and so
    needs neither a block source nor a network name. Every missing required
    setting is reported in one error naming both the flag and the variable. *)
val resolve : requires_blocks:bool -> flags -> t Or_error.t

(** Environment variables the bash guardian used that this app no longer
    needs, each with the reason, so that one still set can be reported and
    ignored rather than silently doing nothing. *)
val obsolete_env_vars_in_use : unit -> (string * string) list

(** The archive URI with every secret replaced, safe to log. See
    {!Archive_uri.redacted}. *)
val redacted_archive_uri : Uri.t -> string
