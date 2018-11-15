(*
   RE - A regular expression library

   Copyright (C) 2001 Jerome Vouillon
   email: Jerome.Vouillon@pps.jussieu.fr

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation, with
   linking exception; either version 2.1 of the License, or (at
   your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
*)

(** Module [Re]: regular expressions commons *)

type t
(** Regular expression *)

type re
(** Compiled regular expression *)

type groups
(** Information about groups in a match. *)

(** {2 Compilation and execution of a regular expression} *)

val compile : t -> re
(** Compile a regular expression into an executable version that can be
    used to match strings, e.g. with {!exec}. *)

val exec :
  ?pos:int ->    (* Default: 0 *)
  ?len:int ->    (* Default: -1 (until end of string) *)
  re -> string -> groups
(** [exec re str] matches [str] against the compiled expression [re],
    and returns the matched groups if any.
    @param pos optional beginning of the string (default 0)
    @param len length of the substring of [str] that can be matched (default [-1],
      meaning to the end of the string
    @raise Not_found if the regular expression can't be found in [str]
*)

val exec_opt :
  ?pos:int ->    (* Default: 0 *)
  ?len:int ->    (* Default: -1 (until end of string) *)
  re -> string -> groups option
(** Similar to {!exec}, but returns an option instead of using an exception. *)

val execp :
  ?pos:int ->    (* Default: 0 *)
  ?len:int ->    (* Default: -1 (until end of string) *)
  re -> string -> bool
(** Similar to {!exec}, but returns [true] if the expression matches,
    and [false] if it doesn't *)

val exec_partial :
  ?pos:int ->    (* Default: 0 *)
  ?len:int ->    (* Default: -1 (until end of string) *)
  re -> string -> [ `Full | `Partial | `Mismatch ]
(** More detailed version of {!exec_p} *)

(** Manipulate matching groups. *)
module Group : sig

  type t = groups
  (** Information about groups in a match. *)

  val get : t -> int -> string
  (** Raise [Not_found] if the group did not match *)

  val offset : t -> int -> int * int
  (** Raise [Not_found] if the group did not match *)

  val start : t -> int -> int
  (** Return the start of the match. Raise [Not_found] if the group did not match. *)

  val stop : t -> int -> int
  (** Return the end of the match. Raise [Not_found] if the group did not match. *)

  val all : t -> string array
  (** Return the empty string for each group which did not match *)

  val all_offset : t -> (int * int) array
  (** Return [(-1,-1)] for each group which did not match *)

  val test : t -> int -> bool
  (** Test whether a group matched *)

  val nb_groups : t -> int
  (** Returns the total number of groups defined - matched or not.
      This function is experimental. *)

  val pp : Format.formatter -> t -> unit

end

(** Marks *)
module Mark : sig

  type t
  (** Mark id *)

  val test : Group.t -> t -> bool
  (** Tell if a mark was matched. *)

  module Set : Set.S with type elt = t

  val all : Group.t -> Set.t
  (** Return all the mark matched. *)

  val equal : t -> t -> bool
  val compare : t -> t -> int

end

(** {2 High Level Operations} *)

type 'a gen = unit -> 'a option

val all :
  ?pos:int ->    (** Default: 0 *)
  ?len:int ->
  re -> string -> Group.t list
(** Repeatedly calls {!exec} on the given string, starting at given
    position and length.*)

val all_gen :
  ?pos:int ->    (** Default: 0 *)
  ?len:int ->
  re -> string -> Group.t gen
(** Same as {!all} but returns a generator *)

val matches :
  ?pos:int ->    (** Default: 0 *)
  ?len:int ->
  re -> string -> string list
(** Same as {!all}, but extracts the matched substring rather than
    returning the whole group. This basically iterates over matched
    strings *)

val matches_gen :
  ?pos:int ->    (** Default: 0 *)
  ?len:int ->
  re -> string -> string gen
(** Same as {!matches}, but returns a generator. *)

val split :
  ?pos:int ->    (** Default: 0 *)
  ?len:int ->
  re -> string -> string list
(** [split re s] splits [s] into chunks separated by [re]. It yields
    the chunks themselves, not the separator. For instance
    this can be used with a whitespace-matching re such as ["[\t ]+"]. *)

val split_gen :
  ?pos:int ->    (** Default: 0 *)
  ?len:int ->
  re -> string -> string gen

type split_token =
  [ `Text of string  (** Text between delimiters *)
  | `Delim of Group.t (** Delimiter *)
  ]

val split_full :
  ?pos:int ->    (** Default: 0 *)
  ?len:int ->
  re -> string -> split_token list

val split_full_gen :
  ?pos:int ->    (** Default: 0 *)
  ?len:int ->
  re -> string -> split_token gen

val replace :
  ?pos:int ->    (** Default: 0 *)
  ?len:int ->
  ?all:bool ->   (** Default: true. Otherwise only replace first occurrence *)
  re ->          (** matched groups *)
  f:(Group.t -> string) ->  (* how to replace *)
  string ->     (** string to replace in *)
  string
(** [replace ~all re ~f s] iterates on [s], and replaces every occurrence
    of [re] with [f substring] where [substring] is the current match.
    If [all = false], then only the first occurrence of [re] is replaced. *)

val replace_string :
  ?pos:int ->    (** Default: 0 *)
  ?len:int ->
  ?all:bool ->   (** Default: true. Otherwise only replace first occurrence *)
  re ->          (** matched groups *)
  by:string ->   (** replacement string *)
  string ->      (** string to replace in *)
  string
(** [replace_string ~all re ~by s] iterates on [s], and replaces every
    occurrence of [re] with [by]. If [all = false], then only the first
    occurrence of [re] is replaced. *)

(** {2 String expressions (literal match)} *)

val str : string -> t
val char : char -> t

(** {2 Basic operations on regular expressions} *)

val alt : t list -> t
(** Alternative *)

val seq : t list -> t
(** Sequence *)

val empty : t
(** Match nothing *)

val epsilon : t
(** Empty word *)

val rep : t -> t
(** 0 or more matches *)

val rep1 : t -> t
(** 1 or more matches *)

val repn : t -> int -> int option -> t
(** [repn re i j] matches [re] at least [i] times
    and at most [j] times, bounds included.
    [j = None] means no upper bound.
*)

val opt : t -> t
(** 0 or 1 matches *)

(** {2 String, line, word} *)

val bol : t
(** Beginning of line *)

val eol : t
(** End of line *)

val bow : t
(** Beginning of word *)

val eow : t
(** End of word *)

val bos : t
(** Beginning of string *)

val eos : t
(** End of string *)

val leol : t
(** Last end of line or end of string *)

val start : t
(** Initial position *)

val stop : t
(** Final position *)

val word : t -> t
(** Word *)

val not_boundary : t
(** Not at a word boundary *)

val whole_string : t -> t
(** Only matches the whole string *)

(** {2 Match semantics} *)

val longest : t -> t
(** Longest match *)

val shortest : t -> t
(** Shortest match *)

val first : t -> t
(** First match *)

(** {2 Repeated match modifiers} *)

val greedy : t -> t
(** Greedy *)

val non_greedy : t -> t
(** Non-greedy *)

(** {2 Groups (or submatches)} *)

val group : t -> t
(** Delimit a group *)

val no_group : t -> t
(** Remove all groups *)

val nest : t -> t
(** when matching against [nest e], only the group matching in the
       last match of e will be considered as matching *)



val mark : t -> Mark.t * t
(** Mark a regexp. the markid can then be used to know if this regexp was used. *)

(** {2 Character sets} *)

val set : string -> t
(** Any character of the string *)

val rg : char -> char -> t
(** Character ranges *)

val inter : t list -> t
(** Intersection of character sets *)

val diff : t -> t -> t
(** Difference of character sets *)

val compl : t list -> t
(** Complement of union *)

(** {2 Predefined character sets} *)

val any : t
(** Any character *)

val notnl : t
(** Any character but a newline *)

val alnum : t
val wordc : t
val alpha : t
val ascii : t
val blank : t
val cntrl : t
val digit : t
val graph : t
val lower : t
val print : t
val punct : t
val space : t
val upper : t
val xdigit : t

(** {2 Case modifiers} *)

val case : t -> t
(** Case sensitive matching *)

val no_case : t -> t
(** Case insensitive matching *)

(****)

(** {2 Internal debugging}  *)

val pp : Format.formatter -> t -> unit

val pp_re : Format.formatter -> re -> unit

(** Alias for {!pp_re}. Deprecated *)
val print_re : Format.formatter -> re -> unit

(** {2 Experimental functions}. *)

val witness : t -> string
(** [witness r] generates a string [s] such that [execp (compile r) s] is
    true *)

(** {2 Deprecated functions} *)

type substrings = Group.t
(** Alias for {!Group.t}. Deprecated *)

val get : Group.t -> int -> string
(** Same as {!Group.get}. Deprecated *)

val get_ofs : Group.t -> int -> int * int
(** Same as {!Group.offset}. Deprecated *)

val get_all : Group.t -> string array
(** Same as {!Group.all}. Deprecated *)

val get_all_ofs : Group.t -> (int * int) array
(** Same as {!Group.all_offset}. Deprecated *)

val test : Group.t -> int -> bool
(** Same as {!Group.test}. Deprecated *)

type markid = Mark.t
(** Alias for {!Mark.t}. Deprecated *)

val marked : Group.t -> Mark.t -> bool
(** Same as {!Mark.test}. Deprecated *)

val mark_set : Group.t -> Mark.Set.t
(** Same as {!Mark.all}. Deprecated *)
