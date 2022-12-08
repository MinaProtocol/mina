module B = struct
  type nonrec bool = bool

  let true_ = true

  let false_ = false

  let if_ b ~then_ ~else_ = if b then then_ () else else_ ()
end

module Bool = struct
  include B

  type t = bool
end

module Tick_field = struct
  include Backend.Tick.Field
  include B
end

module Tock_field = struct
  include Backend.Tock.Field
  include B
end
