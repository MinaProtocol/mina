[@bs.module "./translations/vn.json"]
external vn: array(ReactIntl.translation) = "default";
[@bs.module "./en.json"]
external en: array(ReactIntl.translation) = "default";

type locale =
  | En
  | Vn;

let all = [|En|];

let toString =
  fun
  | En => "en"
  | Vn => "vn";

let translations =
  fun
  | En => en
  | Vn => vn;

// translationsToDict coerces the JSON translation files into a valid data structure
let translationsToDict = (translations: array(ReactIntl.translation)) => {
  translations->Belt.Array.reduce(
    Js.Dict.empty(),
    (dict, entry) => {
      dict->Js.Dict.set(
        entry##id,
        switch (entry##message->Js.Nullable.toOption) {
        | None
        | Some("") => entry##defaultMessage
        | Some(message) => message
        },
      );
      dict;
    },
  );
};