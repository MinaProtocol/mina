(*
  The MIT License (MIT)
  
  Copyright (c) 2016 Maxime Ransan <maxime.ransan@gmail.com>
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

*)

(** Base58 encoding functionality 

    This module implement both encoding and decoding functionality
    for the Base58 encoding.
    More information can be found {{:https://en.wikipedia.org/wiki/Base58}here}. 
    This encoding is well suited to encode large integer values 
    but not large binary data. 
    Both encode and decode have a quadratic performance with 
    respect to the length of the binary data. 
  *)

(** {2 Types} *)

(** An alphabet defines the character associated with a given value
    
    For instance the binary alphabet would ["01"] while the hexadecimal
    one would be ["0123456789ABCDEF"]. 
    
    Since this module only focuses with Base 58 encoding the alphabet must 
    be created with 58 unique characters. 
  *)
type alphabet

exception Invalid_alphabet

(** {2 Alphabet} *)

(** [make_alphabet s] creates a base 58 alphabet.
    
    If [s] length is different than 58 characters then [Invalid_alphabet] 
    exception is raised.
  *)
val make_alphabet : string -> alphabet

(** {2 Decoding/Encoding} *)

(** [encode alphabet data] encodes [data] using [alphabet]. 
  *)
val encode : alphabet -> bytes -> bytes

exception Invalid_base58_character

(** [decode alphabet data] decodes [data] using [alphabet]. 
    
    If [data] contains character not included in [alphabet], 
    [Invalid_base58_character] exception is raised.
  *)
val decode : alphabet -> bytes -> bytes
