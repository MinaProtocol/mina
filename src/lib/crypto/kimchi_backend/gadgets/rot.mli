(* Side of rotation *)
type direction = Left | Right

(* 64bit rotation gadget
 *   Inputs:
 *     word      := Word to rotation (as CVar field element)
 *     rot_bits  := How many bit positions to rotate by 0 to 64
 *     direction := Left | Right
 *   Output: rotated word
 *)
val bits64 :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t (* word *)
  -> int (* rot_bits *)
  -> direction (* direction*)
  -> 'f Snarky_backendless.Cvar.t
(* rotated word *)
