module Styles = {
  open Css;
  let square = (bgColor, textColor, borderColor) =>
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexStart),
      alignItems(`center),
      height(`rem(24.)),
      width(`rem(24.)),
      backgroundColor(bgColor),
      selector("h1", [color(textColor), fontFamily(Fonts.ibmplexsans)]),
      borderRadius(`px(6)),
      border(`px(2), `solid, borderColor),
      boxShadow(
        Shadow.box(
          ~x=`zero,
          ~y=`px(10),
          ~blur=`px(30),
          `rgba((61, 88, 120, 0.25)),
        ),
      ),
    ]);

  let blockText = (textColor, textSize, top) =>
    style([
      marginTop(top),
      height(`rem(20.)),
      width(`rem(20.)),
      overflowWrap(`breakWord),
      fontFamily(Fonts.ocrastud),
      fontSize(textSize),
      color(textColor),
    ]);
  let heading = style([fontFamily("Aktiv Grotesk Bold")]);
  
  let blink = keyframes([(0, [opacity(1.)]), (100, [opacity(0.3)])]);

  let blinkingSquare = (bgColor, textColor, borderColor) =>
    merge([
      square(bgColor, textColor, borderColor),
      style([animation(blink, ~duration=1000, ~iterationCount=`infinite), animationDirection(`alternate)]),
    ]);
  let blinkingText = (textColor, textSize, top) =>
    merge([
      blockText(textColor, textSize, top),
      style([animation(blink, ~duration=1000, ~iterationCount=`infinite), animationDirection(`alternate)]),
    ]);
  let blinkingHeading =
    merge([
      heading,
      style([animation(blink, ~duration=1000, ~iterationCount=`infinite), animationDirection(`alternate)]),
    ]);
 let blinking = style([animation(blink, ~duration=1000, ~iterationCount=`infinite), animationDirection(`alternate)]);
};

[@react.component]
let make =
    (
      ~bgColor,
      ~textColor,
      ~borderColor,
      ~heading="",
      ~text={React.string("")},
      ~textSize=`rem(1.56),
      ~marginTop=`zero, 
      ~active,
    ) =>
    {
            Js.log(active);

    <div
    className={
      active
        ? Styles.square(
            Colors.thirdBgActive,
            Colors.offWhite,
            Colors.thirdBgActive,
          )
        : Styles.blinkingSquare(bgColor, textColor, borderColor)
    }>
    
        <h1 className={ active ? Styles.heading : Styles.blinkingHeading}> {React.string(heading)} </h1>
    
    <div
      className={
        active
          ? Styles.blockText(Colors.offWhite, textSize, marginTop)
          : Styles.blinkingText(textColor, textSize, marginTop)
      }>
      text
    </div>
  </div>
    }
;
