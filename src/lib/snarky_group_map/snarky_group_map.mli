module Params : sig
  type 'f t = 'f Group_map.Params.t

  val create :
       (module Group_map.Field_intf.S_unchecked with type t = 'f)
    -> 'f Group_map.Spec.t
    -> 'f t
end

val to_group :
     (module Group_map.Field_intf.S_unchecked with type t = 'f)
  -> params:'f Params.t
  -> 'f
  -> 'f * 'f

module Checked : sig
  open Snarky_backendless

  val wrap :
       (module Snark_intf.Run with type field = 'f and type field_var = 'v)
    -> potential_xs:('input -> 'v * 'v * 'v)
    -> y_squared:(x:'v -> 'v)
    -> ('input -> 'v * 'v) Core_kernel.Staged.t

  val to_group :
       (module Snark_intf.Run with type field = 'f and type field_var = 'v)
    -> params:'f Params.t
    -> 'v
    -> 'v * 'v
end
