// [@bs.module "./translations/vn.json"]
// external vn: array(ReactIntl.translation) = "default";
// [@bs.module "./en.json"]
// external en: array(ReactIntl.translation) = "default";
type locale =
  | En
  | Vn;

let all = [|En|];

let toString =
  fun
  | En => "en"
  | Vn => "vn";

external jsonToTranslations: Js.Json.t => array(ReactIntl.translation) =
  "%identity";

[@bs.val] [@bs.scope "window"]
external getTranslation: string => string = "getTranslation";

let fileToReactIntl = name => {
  Js.log(name)
  let file = getTranslation(name);
  jsonToTranslations(Js.Json.parseExn(file));
};

let translations =
  fun
  | En => fileToReactIntl("en")
  | Vn => fileToReactIntl("vn");

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