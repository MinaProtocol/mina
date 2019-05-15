open Tc;

module Styles = {
  open Css;

  let container = isOpen =>
    style([
      position(`relative),
      display(`flex),
      flexGrow(1.),
      alignItems(`center),
      justifyContent(`flexStart),
      height(`rem(2.5)),
      width(`percent(100.)),
      padding2(~v=`zero, ~h=`rem(0.75)),
      background(white),
      border(`px(1), `solid, Theme.Colors.marineAlpha(0.3)),
      borderRadius(`rem(0.25)),
      borderBottomLeftRadius(isOpen ? `zero : `rem(0.25)),
      borderBottomRightRadius(isOpen ? `zero : `rem(0.25)),
    ]);

  let label =
    merge([
      Theme.Text.smallHeader,
      style([
        textTransform(`uppercase),
        color(Theme.Colors.slateAlpha(0.7)),
      ]),
    ]);

  let value =
    merge([
      Theme.Text.Body.regular,
      style([paddingBottom(`px(2)), color(Theme.Colors.teal)]),
    ]);

  let hidden = style([display(`none)]);
  let options =
    style([
      position(`absolute),
      top(`percent(100.)),
      left(`px(-1)),
      right(`px(-1)),
      maxHeight(`rem(10.)),
      overflow(`scroll),
      background(white),
      border(`px(1), `solid, Theme.Colors.marineAlpha(0.3)),
      borderBottomLeftRadius(`rem(0.25)),
      borderBottomRightRadius(`rem(0.25)),
    ]);

  let item =
    merge([
      Theme.Text.Body.regular,
      style([
        height(`rem(2.5)),
        display(`flex),
        alignItems(`center),
        padding2(~v=`zero, ~h=`rem(1.)),
        color(Theme.Colors.teal),
        hover([backgroundColor(Theme.Colors.slateAlpha(0.1))]),
      ]),
    ]);
};

[@react.component]
let make = (~onChange, ~value, ~label, ~options) => {
  let (isOpen, setOpen) = React.useState(() => false);
  let toggleOpen = () => setOpen(isOpen => !isOpen);
  <div className={Styles.container(isOpen)} onClick={_e => toggleOpen()}>
    <span className=Styles.label> {React.string(label ++ ":")} </span>
    <Spacer width=0.5 />
    <span className=Styles.value> {React.string(value)} </span>
    <div className={isOpen ? Styles.options : Styles.hidden}>
      {List.map(
         ~f=
           item =>
             <div className=Styles.item onClick={_e => onChange(item)}>
               {React.string(item)}
             </div>,
         options,
       )
       |> Array.fromList
       |> React.array}
    </div>
  </div>;
};
