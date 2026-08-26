(** The health probes themselves: what [rosetta-healthcheck] asks a
    Rosetta server, and how it decides whether the answer is healthy.

    Nothing here touches [Command], prints, or exits.  A probe returns a
    typed verdict and leaves the presentation of it — text or JSON, which
    exit code — to {!Rosetta_healthcheck}.  That split is what makes the
    decisions testable without spawning the binary. *)

(** The chain tip as [/network/status] reported it. *)
type tip =
  { height : int64
  ; hash : string
  ; age_seconds : int64
        (** Age of [timestamp] at the moment of the probe, never
            negative: a server whose clock runs ahead of ours reports 0
            rather than a negative age. *)
  ; fresh : bool  (** Whether [age_seconds] is within the caller's bound. *)
  }

(** Verdict of the composite readiness check. *)
type readiness =
  { ready : bool  (** True only when [problems] is empty. *)
  ; tip : tip option
        (** The tip, when [/network/status] answered — present even when
            the tip was too old, so a caller can report how far behind
            the server is. *)
  ; problems : string list  (** One line per failed check, in probe order. *)
  }

(** [connectivity client ~expected_blockchain ~expected_network] asks
    [/network/list] and returns everything the server advertises.

    It is an error when the server answers with an empty list, or when
    the expected pair is absent — the error message then names the
    advertised set, because "wrong network" and "server not up" need
    different fixes. *)
val connectivity :
     Rosetta_client.Http.t
  -> expected_blockchain:string
  -> expected_network:string
  -> Rosetta_client.Models.Network_identifier.t list Async.Deferred.Or_error.t

(** [tip_recency client ~max_age] asks [/network/status] and reports the
    tip with its age.  A tip older than [max_age] seconds is returned
    with [fresh = false] rather than as an error: the caller still wants
    the height and the age in order to report them. *)
val tip_recency :
  Rosetta_client.Http.t -> max_age:int -> tip Async.Deferred.Or_error.t

(** [readiness client ~expected_blockchain ~expected_network ~max_age]
    runs {!connectivity}, {!tip_recency} and a [/network/options] sanity
    check.

    Every check runs even after an earlier one failed, so one invocation
    reports every problem instead of only the first — an operator
    debugging a sick server wants the whole picture at once.  For that
    reason this returns a plain [Deferred.t]: a transport failure is an
    entry in [problems], not an error channel that would short-circuit
    the remaining checks. *)
val readiness :
     Rosetta_client.Http.t
  -> expected_blockchain:string
  -> expected_network:string
  -> max_age:int
  -> readiness Async.Deferred.t
