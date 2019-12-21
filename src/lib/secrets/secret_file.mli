(** Encrypted secrets stored in a file.

This module implements SSH-style "private key files", ensuring that the files are only accessible to the user that created them.

{b NOTE:} this will _erase_ the contents of forced [password] arguments. If you stash them somewhere (you shouldn't outside of tests), you should copy the string before you return it.
*)

open Core
open Async

type password = Bytes.t Deferred.t Lazy.t

(** Read from the secure file [path], using [password] to decrypt if the file permissions are OK. This means that the file itself has permissions 0600 and the directory containing it has permissions 0700.

[password] is only forced if the file has secure permissions.
*)
val read :
     path:string
  -> password:password
  -> (Bytes.t, Privkey_error.t) Deferred.Result.t

(** Write [contents] to [path], after wrapping it in a [Secret_box] with [password].

This will make the file if it doesn't exist and set permissions such that [read] will succeed. If [mkdir] is true, it will also do the equivalent of {v mkdir -p $path ; chmod 700 $(dirname $path) v}.

If the file already exists, permissions are checked.

[password] is only forced if opening the file is successful, to avoid unnecessary and annoying interactive prompts.
*)
val write :
     path:string
  -> mkdir:bool
  -> password:password
  -> plaintext:Bytes.t
  -> (unit, Privkey_error.t) Deferred.Result.t
