type t = [ `Cache_hit | `Generated_something | `Locally_generated ]

val ( + ) :
     [< `Cache_hit | `Generated_something | `Locally_generated ]
  -> [< `Cache_hit | `Generated_something | `Locally_generated ]
  -> [> `Cache_hit | `Generated_something | `Locally_generated ]
