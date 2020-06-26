include Field.Make (struct
  module Bigint = Bigint.T384
  include Snarky_bn382.Fq
end)
