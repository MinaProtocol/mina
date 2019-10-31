module Styles = {
  open Css;

  let blockRow =
    style([
      display(`grid),
      gridTemplateColumns([
        `rem(23.0),
        `rem(10.0),
        `rem(23.0),
        `rem(10.0),
        `rem(23.0),
      ]),
      gridTemplateRows([`repeat((`num(1), `rem(23.)))]),
      gridColumnGap(`zero),
      justifyContent(`spaceBetween),
      position(`absolute),
      top(`calc((`sub, `percent(50.), `rem(10.0)))),
      left(`calc((`sub, `percent(50.), `rem(45.0)))),
    ]);

  let firstLine =
    style([
      display(`inlineBlock),
      borderTop(`px(10), `solid, Colors.marine),
      width(`rem(10.)),
      margin2(~v=`rem(11.0), ~h=`zero),
      zIndex(-1),
    ]);

  let blink = keyframes([(0, []), (100, [opacity(0.)])]);

  let secondLine =
    style([
      display(`inlineBlock),
      borderTop(`px(10), `dashed, Colors.moss),
      width(`rem(10.)),
      margin2(~v=`rem(11.0), ~h=`zero),
      zIndex(-1),
      animation(blink, ~duration=1000, ~iterationCount=`infinite),
    ]);
};

[@react.component]
let make = (~verified as _) => {
  <div className=Styles.blockRow>
    <Square
      bgColor=Colors.firstBg
      textColor=Colors.saville
      borderColor=Colors.navyBlue
      heading="Last Block"
      text="Time Since"
      timer=true
    />
    <span className=Styles.firstLine />
    <Square
      bgColor=Colors.secondBg
      textColor=Colors.hyperlink
      borderColor=Colors.secondBorder
      heading="Latest Snark"
      text="4ApWEzSMKEsaPF6rYx6Vh6VBbHmxupj8C1EzQDyQDtcbqfmg3pnwtaFrAXWZs4QrhNHj8UtFhp3Af66M1uvoqTBy5RPe3JQmHHwYcPooZSMZgppvrCRxQ1c3DaoQh3heBXCuNAofL8hQv"
    />
    <span className=Styles.secondLine />
    <Square
      bgColor=Colors.thirdBg
      textColor=Colors.jungle
      borderColor=Colors.thirdBg
      heading="Verified!"
      text="4ApWEzSMKEsaPF6rYx6Vh6VBbHmxupj8C1EzQDyQDtcbqfmg3pnwtaFrAXWZs4QrhNHj8UtFhp3Af66M1uvoqTBy5RPe3JQmHHwYcPooZSMZgppvrCRxQ1c3DaoQh3heBXCuNAofL8hQv"
    />
  </div>;
};
