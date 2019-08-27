open Tc;
open Bindings;

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
      focus([outlineStyle(`none)]),
    ]);

  let label =
    merge([
      Theme.Text.Header.h6,
      style([
        textTransform(`uppercase),
        color(Theme.Colors.slateAlpha(0.7)),
        cursor(`default),
        minWidth(`rem(2.5)),
      ]),
    ]);

  let value =
    merge([
      Theme.Text.Body.regular,
      style([
        paddingBottom(`px(2)),
        color(Theme.Colors.teal),
        flexGrow(1.),
      ]),
    ]);

  let hidden = style([display(`none)]);
  let options =
    style([
      position(`absolute),
      top(`percent(100.)),
      left(`px(-1)),
      right(`px(-1)),
      maxHeight(`calc((`add, `rem(10.), `px(2)))),
      overflow(`scroll),
      background(white),
      border(`px(1), `solid, Theme.Colors.marineAlpha(0.3)),
      borderBottomLeftRadius(`rem(0.25)),
      borderBottomRightRadius(`rem(0.25)),
      cursor(`default),
      zIndex(1),
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

  let icon =
    style([
      color(Theme.Colors.tealAlpha(0.5)),
      height(`rem(1.5)),
      marginRight(`px(-5)),
    ]);
};

[@react.component]
let make =
    (
      ~onChange,
      ~value,
      ~label,
      ~disabled=false,
      ~options: list((string, React.element)),
    ) => {
  let (isOpen, setOpen) = React.useState(() => false);
  let toggleOpen = () => setOpen(isOpen => !isOpen);

  let currentLabel =
    value
    |> Option.map(~f=v => Caml.List.assoc(v, options))
    |> Option.withDefault(~default=React.string(""));

  Window.onClick(Window.current, () => setOpen(_ => false));
  <div
    className={Styles.container(isOpen)}
    onClick={e => {
      ReactEvent.Mouse.stopPropagation(e);
      if (!disabled) {
        toggleOpen();
      };
    }}>
    <span className=Styles.label> {React.string(label ++ ":")} </span>
    <Spacer width=0.5 />
    <span className=Styles.value> currentLabel </span>
    <Spacer width=0.5 />
    <span className=Styles.icon> <Icon kind=Icon.ChevronDown /> </span>
    <div className={isOpen ? Styles.options : Styles.hidden}>
      {List.map(
         ~f=
           ((value, label)) =>
             <div
               key=value
               className=Styles.item
               onClick={_e => onChange(value)}>
               label
             </div>,
         options,
       )
       |> Array.fromList
       |> React.array}
    </div>
  </div>;
};
