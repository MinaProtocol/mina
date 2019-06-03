module type Inputs_intf = sig
  include Coda_intf.Inputs_intf

  val max_length : int
end
