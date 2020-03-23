module Style = {
  open Css;
  let containerWidth = `rem(37.);
  let wrapper = style([display(`flex), flexDirection(`column)]);
  let container =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
      justifyContent(`flexStart),
      width(`rem(18.)),
      height(`rem(15.)),
      maxWidth(`percent(100.)),
      backgroundColor(Theme.Colors.midnight),
      color(Theme.Colors.offWhite),
      padding(`rem(1.)),
      Theme.Typeface.ibmplexmono,
      borderBottomLeftRadius(`px(5)),
      borderBottomRightRadius(`px(5)),
      media(
        Theme.MediaQuery.notMobile,
        [width(containerWidth), height(`rem(22.)), padding(`rem(2.))],
      ),
    ]);
  let item =
    style([
      marginBottom(`rem(0.5)),
      fontSize(`rem(0.7)),
      media(Theme.MediaQuery.notMobile, [fontSize(`rem(1.2))]),
    ]);
  let prompt = style([color(Theme.Colors.grey), marginRight(`rem(1.))]);
  let header =
    style([
      position(`relative),
      display(`flex),
      backgroundColor(Theme.Colors.darkGreyBlue),
      height(`rem(2.)),
      alignItems(`center),
      color(Theme.Colors.grey),
      borderTopLeftRadius(`px(5)),
      borderTopRightRadius(`px(5)),
    ]);
  let circles =
    style([
      position(`absolute),
      display(`flex),
      alignItems(`center),
      marginLeft(`rem(0.5)),
    ]);
  let circle = c =>
    style([
      backgroundColor(c),
      height(`rem(0.75)),
      width(`rem(0.75)),
      borderRadius(`rem(0.375)),
      margin2(~v=`zero, ~h=`rem(0.5)),
    ]);
  let headerText =
    style([
      alignSelf(`center),
      justifySelf(`center),
      marginLeft(`auto),
      marginRight(`auto),
      Theme.Typeface.ibmplexmono,
    ]);
};

let useIncrement = (~initial, ~total, ~increment, ~delay) => {
  let (amount, setAmount) = React.useState(() => initial);
  React.useEffect1(
    () =>
      if (total > amount) {
        let id =
          Js.Global.setTimeout(
            () => setAmount(n => min(total, n + increment)),
            delay,
          );
        Some(() => Js.Global.clearTimeout(id));
      } else {
        None;
      },
    [|amount|],
  );
  amount;
};

module Wrapper = {
  [@react.component]
  let make = (~lineDelay, ~children) => {
    let arr = ReactExt.Children.toArray(children);
    let total = Array.length(arr);
    let numDisplayed =
      useIncrement(
        ~initial=min(total, 1),
        ~total,
        ~increment=1,
        ~delay=lineDelay,
      );
    <div className=Style.wrapper>
      <div className=Style.header>
        <div className=Style.headerText> {React.string("bash")} </div>
        <div className=Style.circles>
          <div className={Style.circle(Theme.Colors.rosebud)} />
          <div className={Style.circle(Theme.Colors.amber)} />
          <div className={Style.circle(Theme.Colors.clover)} />
        </div>
      </div>
      <div className=Style.container>
        {React.array(Array.sub(arr, 0, numDisplayed))}
      </div>
    </div>;
  };
};

module Line = {
  [@react.component]
  let make = (~delay=75, ~prompt=?, ~value) => {
    let numDisplayed =
      useIncrement(
        ~initial=delay == 0 ? String.length(value) : 0,
        ~total=String.length(value),
        ~increment=1,
        ~delay,
      );
    let displayed = String.sub(value, 0, numDisplayed);
    <div className=Style.item>
      {ReactExt.fromOpt(
         ~f=
           prompt =>
             <span className=Style.prompt> {React.string(prompt)} </span>,
         prompt,
       )}
      {React.string(displayed)}
    </div>;
  };
};

module MultiLine = {
  [@react.component]
  let make = (~values) => {
    <>
      {values
       |> Array.mapi((i, v) => {
            <div key={string_of_int(i)} className=Style.item>
              {React.string(v)}
            </div>
          })
       |> React.array}
    </>;
  };
};

module Progress = {
  [@react.component]
  let make = (~delay=4, ~char={js|█|js}) => {
    let total = 100;
    let numDisplayed = useIncrement(~initial=0, ~total, ~increment=1, ~delay);
    let numChars = numDisplayed / 3;
    let displayed = String.concat("", List.init(numChars, _ => char));
    <div className=Style.item>
      {React.string(displayed)}
      {React.string(" " ++ string_of_int(numDisplayed) ++ "%")}
    </div>;
  };
};
