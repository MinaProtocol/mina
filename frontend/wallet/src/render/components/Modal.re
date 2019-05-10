/* open Tc; */

type document;
[@bs.send] external getElementById: (document, string) => Dom.element = "";
[@bs.val] external document: document = "";

module Styles = {
  open Css;

  let inner =
    style([
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

  let outer =
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
      backgroundColor(Theme.Colors.modalDisableBgAlpha(0.67))
    ]);
};

[@react.component]
let make = (~onClickOutside, ~children) => {
  ReactDOMRe.createPortal(
    <div className=Styles.outer onClick={_ => onClickOutside()}>
      <div
        className=Styles.inner
        onClick={e => ReactEvent.Mouse.stopPropagation(e)}>
        children
      </div>
    </div>,
    getElementById(document, "modal"),
  );
};
