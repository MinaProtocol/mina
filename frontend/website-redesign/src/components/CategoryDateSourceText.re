module Styles = {
  open Css;

  let category = style([fontWeight(`bold)]);
};

type t = {
  category: string,
  date: string,
  source: string,
};

[@react.component]
let make = (~metadata) => {
  let {category, date, source} = metadata;
  <div className=Theme.Type.metadata>
    <span className=Styles.category> {React.string(category)} </span>
    <span> {React.string(" / ")} </span>
    <span> {React.string(date)} </span>
    <span> {React.string(" / ")} </span>
    <span> {React.string(source)} </span>
  </div>;
};
