// TODO: If we start to get crazy routes, we should implement
// http://www.informatik.uni-marburg.de/~rendel/unparse/
// as demonstrated in https://github.com/pointfreeco/swift-web/

// Law: All route handlers are idempotent!
// (1) It's a good user experience to _see_ what's going to happen in the UI
//     before actions happen
// (2) Other code depends on this property

open Tc;

module Path = {
  type t =
    | Send
    | DeleteWallet // TODO: include wallet id in payload
    | Home;

  module Decode = {
    let parse =
      fun
      | "send" => Some(Send)
      | "wallet/delete" => Some(DeleteWallet)
      | "" => Some(Home)
      | _ => None;

    let t = json =>
      Json.Decode.string(json)
      |> parse
      |> Option.withDefault(
           ~default=raise(Json.Decode.DecodeError("Path can't parse")),
         );
  };

  module Encode = {
    let print =
      fun
      | Send => "send"
      | DeleteWallet => "wallet/delete"
      | Home => "";

    let t = t => Json.Encode.string(print(t));
  };
};

module SettingsOrError = {
  type t = [
    | `Error(
        [
          | `Decode_error(string)
          | `Error_reading_file(Js.Exn.t)
          | `Json_parse_error
        ],
      )
    | `Settings(Settings.t)
  ];

  module Encode = {
    let tagged = (name, x) => Json.Encode.object_([(name, x)]);

    let exnToString = exn => {
      let orEmpty = Option.withDefault(~default="");
      orEmpty(Js.Exn.name(exn))
      ++ "%%"
      ++ orEmpty(Js.Exn.message(exn))
      ++ "%%"
      ++ orEmpty(Js.Exn.stack(exn));
    };

    let t =
      fun
      | `Settings(settings) =>
        tagged("settings", Settings.Encode.t(settings))
      | `Error(e) =>
        tagged(
          "error",
          switch (e) {
          | `Decode_error(s) => tagged("decode_error", Json.Encode.string(s))
          | `Error_reading_file(exn) =>
            tagged(
              "error_reading_file",
              Json.Encode.string(exnToString(exn)),
            )
          | `Json_parse_error =>
            tagged("json_parse_error", Json.Encode.int(0))
          },
        );
  };

  module Decode = {
    let settings =
      Json.Decode.field("settings", json =>
        `Settings(Settings.Decode.t(json))
      );

    module Error = {
      type t;
      [@bs.new]
      external create: (~name: string, ~message: string, ~stack: string) => t =
        "Error";
    };

    let exnOfString = s => {
      switch (Js.String.split("%%", s)) {
      | [|name, message, stack|] =>
        Obj.magic(Error.create(~name, ~message, ~stack))
      | _ =>
        raise(Json.Decode.DecodeError("Info for exn not formatted properly"))
      };
    };

    let t = json =>
      json
      |> Json.Decode.oneOf([
           Json.Decode.field("settings", json =>
             `Settings(Settings.Decode.t(json))
           ),
           Json.Decode.field("error", json =>
             `Error(
               json
               |> Json.Decode.oneOf([
                    Json.Decode.field("decode_error", json =>
                      `Decode_error(Json.Decode.string(json))
                    ),
                    Json.Decode.field("error_reading_file", json =>
                      `Error_reading_file(
                        exnOfString(Json.Decode.string(json)),
                      )
                    ),
                    Json.Decode.field("json_parse_error", _ =>
                      `Json_parse_error
                    ),
                  ]),
             )
           ),
         ]);
  };
};

type t = {
  path: Path.t,
  settingsOrError: SettingsOrError.t,
};

let print = ({path, settingsOrError}) => {
  Path.Encode.print(path)
  ++ "?settingsOrError="
  ++ (
    SettingsOrError.Encode.t(settingsOrError)
    |> Json.stringify
    |> Js.Global.encodeURI
  );
};

let parse = s => {
  switch (Js.String.split("?settingsOrError=", s)) {
  | [|path, settingsOrError|] =>
    let settingsOrError = Js.Global.decodeURI(settingsOrError);
    Option.map2(
      Path.Decode.parse(path),
      // TODO: Catch the decode errors (parseOrRaise + SettingsOrError.Decode.t)
      Some(Json.parseOrRaise(settingsOrError))
      |> Option.map(~f=SettingsOrError.Decode.t),
      ~f=(path, settingsOrError) =>
      {path, settingsOrError}
    );
  | _ => None
  };
};
