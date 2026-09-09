(** The verification keys the daemon hands to its verifier subprocess.

    Computing these applies the transaction and blockchain SNARK functors, which
    costs around 30 seconds and peaks at ~2.6GB of memory. Packaged nodes read
    them from a file installed alongside the runtime config instead. *)

type keys =
  { blockchain : Pickles.Verification_key.t
  ; transaction : Pickles.Verification_key.t
  }

(** Where a package installs the keys. *)
val default_path : string

(** Resolves the keys, in this order: a dummy pair for proof levels that never
    verify a real proof; [path] if the operator named one; [default_path] if it
    exists and fits; otherwise computed in this process.

    A file is only used when it was generated for these constraint constants and
    this signature kind, since otherwise its keys would reject every block. A
    file at [path] that is missing or does not fit raises, because naming it is
    a claim that it belongs to this node; the installed file at [default_path]
    is ignored with a warning instead, so that a config which overrides a proof
    constant still starts. *)
val load :
     logger:Logger.t
  -> ?default_path:string
  -> path:string option
  -> signature_kind:Mina_signature_kind.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> unit
  -> keys Async.Deferred.t

(** Reads a key file, checking that it was generated for these constants. Fails
    if it was not, since its keys would then reject every block. *)
val of_file :
     signature_kind:Mina_signature_kind.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> string
  -> keys Core.Or_error.t

(** Computes the keys and writes them to the given path. Used to generate the
    files that ship with a release. *)
val compute_and_save :
     signature_kind:Mina_signature_kind.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> string
  -> unit Async.Deferred.t
