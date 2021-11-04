open Core

module Puppeteer_message = struct
  type t =
    { puppeteer_script_event : bool
    ; puppeteer_event_type : string
    ; message : string
    }
  [@@deriving yojson]
end
