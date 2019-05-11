module Styles = {
  open Css;

  let content =
    style([
      outlineStyle(`none),
      width(Theme.Spacing.modalWidth),
      minHeight(`rem(10.)),
      backgroundColor(Theme.Colors.bgColor),
      borderRadius(`px(12)),
      padding(`px(12)),
      boxShadow(
        ~x=`zero,
        ~y=`zero,
        ~blur=`px(50),
        ~spread=`px(2),
        `rgba((0, 0, 0, 0.5)),
      ),
    ]);

  let overlay =
    style([
      position(`fixed),
      left(`zero),
      top(`zero),
      right(`zero),
      bottom(`zero),
      display(`flex),
      justifyContent(`center),
      alignItems(`center),
      width(`percent(100.)),
      height(`percent(100.)),
      backgroundColor(Theme.Colors.modalDisableBgAlpha(0.67)),
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
      ~children: React.element
    ) =>
    React.element =
    "react-modal";
};

// Wrap react-modal with a default style
[@react.component]
let make = (~isOpen, ~onRequestClose, ~contentLabel, ~children) =>
  <Binding
    isOpen
    onRequestClose
    contentLabel
    className=Styles.content
    overlayClassName=Styles.overlay>
    children
  </Binding>;
