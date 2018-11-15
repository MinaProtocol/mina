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

(* Character sets, represented as sorted list of intervals *)

type c = int
type t

val iter : t -> f:(c -> c -> unit) -> unit

val union : t -> t -> t
val inter : t -> t -> t
val diff : t -> t -> t
val offset : int -> t -> t

val empty : t
val single : c -> t
val seq : c -> c -> t
val add : c -> t -> t

val mem : c -> t -> bool

type hash
val hash : t -> hash

val pp : Format.formatter -> t -> unit

val one_char : t -> c option

val fold_right : t -> init:'acc -> f:(c * c -> 'acc ->  'acc) -> 'acc

val hash_rec : t -> int

module CSetMap : Map.S with type key = int * t

val cany : t

val csingle : char -> t

val is_empty : t -> bool

val prepend : t -> 'a list -> (t * 'a list) list -> (t * 'a list) list

val pick : t -> c
