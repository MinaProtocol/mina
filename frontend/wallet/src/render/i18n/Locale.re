external jsonToTranslations: Js.Json.t => array(ReactIntl.translation) =
  "%identity";

[@bs.val] [@bs.scope "window"]
external getTranslation: string => string = "getTranslation";

type locale =
  | En
  | Vn;

let all = [|En|];

let toString =
  fun
  | En => "en"
  | Vn => "vn";

// fileToReactIntl transforms the raw json into a Reason data structure
let fileToReactIntl = name => {
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

module Hooks = {
  type action =
    | SetLocale(locale);

  let useLocale = () => {
    let initialState = En;

    let intlReducer = (_, action) =>
      switch (action) {
      | SetLocale(locale) => locale
      };

    let (locale, setLocale) = React.useReducer(intlReducer, initialState);

    (locale, setLocale);
  };
};