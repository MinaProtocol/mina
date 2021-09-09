module Styles = {
  open Css;
  let title = isRed =>
    merge([
      Theme.Text.title,
      style([
        color(isRed ? Theme.Colors.roseBud : Theme.Colors.teal),
        textAlign(`center),
        margin(`zero),
        padding2(~v=`rem(0.), ~h=`rem(1.)),
      ]),
    ]);

  let content =
    merge([
      Window.Styles.bg,
      style([
        outlineStyle(`none),
        width(Theme.Spacing.modalWidth),
        minHeight(`rem(10.)),
        borderRadius(`px(12)),
        padding(`rem(2.)),
        boxShadow(
          ~x=`zero,
          ~y=`zero,
          ~blur=`px(50),
          ~spread=`px(2),
          `rgba((0, 0, 0, 0.5)),
        ),
      ]),
    ]);

  let overlay =
    style([
      position(`fixed),
      left(`zero),
      top(`zero),
      right(`zero),
      bottom(`zero),
      zIndex(999),
      display(`flex),
      justifyContent(`center),
      alignItems(`center),
      width(`percent(100.)),
      height(`percent(100.)),
      backgroundColor(Theme.Colors.modalDisableBgAlpha(0.67)),
    ]);

  let default =
    style([
      margin(`auto),
      width(`rem(22.)),
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`center),
    ]);
};

module Binding = {
  [@react.component] [@bs.module]
  external make:
    (
      ~isOpen: bool,
      ~onRequestClose: unit => unit,
      ~contentLabel: string,
      ~className: string=?,
      ~overlayClassName: string=?,
      ~appElement: Dom.element,
      ~children: React.element
    ) =>
    React.element =
    "react-modal";

  type document;
  [@bs.val] external document: document = "document";
  [@bs.send] external getElementById: (document, string) => Dom.element = "getElementById";
};

// Wrap react-modal with a default style
[@react.component]
let make = (~isRed=false, ~onRequestClose, ~title, ~children) =>
  <Binding
    isOpen=true
    onRequestClose
    contentLabel=title
    appElement={Binding.getElementById(Binding.document, "index")}
    className=Styles.content
    overlayClassName=Styles.overlay>
    <h1 className={Styles.title(isRed)}> {React.string(title)} </h1>
    <Spacer height=1. />
    children
  </Binding>;
