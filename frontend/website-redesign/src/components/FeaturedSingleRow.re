module Styles = {
  open Css;

  let singleRowBackground =
    style([
      height(`percent(100.)),
      width(`percent(100.)),
      important(backgroundSize(`cover)),
      backgroundImage(`url("/static/img/FeaturedSingleRowBackground.png")),
    ]);

  let container =
    style([
      position(`relative),
      width(`percent(100.)),
      height(`px(658)),
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      media(Theme.MediaQuery.notMobile, []),
    ]);

  let contentBlock =
    style([
      position(`absolute),
      width(`percent(90.)),
      bottom(`percent(6.)),
      margin2(~h=`rem(5.), ~v=`zero),
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
      justifyContent(`spaceBetween),
      padding(`rem(3.)),
      important(backgroundSize(`cover)),
      backgroundImage(`url("/static/img/TestnetContentBlockBackground.png")),
      media(
        Theme.MediaQuery.tablet,
        [
          margin(`zero),
          right(`zero),
          bottom(`percent(40.)),
          height(`rem(20.)),
          width(`rem(29.)),
        ],
      ),
    ]);

  let copyText =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
    ]);

  let title = merge([Theme.Type.h2, style([color(Theme.Colors.white)])]);

  let description =
    merge([
      Theme.Type.sectionSubhead,
      style([marginTop(`rem(1.)), color(Theme.Colors.white)]),
    ]);

  let image =
    style([
      position(`absolute),
      bottom(`zero),
      width(`percent(100.)),
      height(`percent(110.)),
      maxWidth(`px(848)),
    ]);
};

[@react.component]
let make = () => {
  <div className=Styles.singleRowBackground>
    <Wrapped>
      <div className=Styles.container>
        <img src="/static/img/NodeOpsTestnet.png" className=Styles.image />
        <div className=Styles.contentBlock>
          <span className=Styles.copyText>
            <h2 className=Styles.title> {React.string("Testnet")} </h2>
            <p className=Styles.description>
              {React.string(
                 "Check out what's in beta, take on Testnet challenges and earn Testnet points.",
               )}
            </p>
          </span>
          <span>
            <Button bgColor=Theme.Colors.orange dark=true>
              {React.string("Go To Testnet")}
              <Icon kind=Icon.ArrowRightMedium />
            </Button>
          </span>
        </div>
      </div>
    </Wrapped>
  </div>;
};
