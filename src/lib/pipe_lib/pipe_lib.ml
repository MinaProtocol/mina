module Broadcast_pipe = Broadcast_pipe
module Linear_pipe = Linear_pipe

module Strict_pipe = struct
  include Strict_pipe
  module Replaceable = Replaceable_strict_pipe
end
