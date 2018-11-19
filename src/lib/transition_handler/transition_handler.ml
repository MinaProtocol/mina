(*
module Make (Inputs : Inputs_intf) : Transaction_handler_intf = struct
  module Validator = Validator.Make (Inputs)
  module Processor = Processor.Make (Inputs)
end
 *)
