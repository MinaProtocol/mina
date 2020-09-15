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

  let buttonText =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      width(`percent(100.)),
      fontSize(`rem(0.7)),
    ]);

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
      height(`percent(100.)),
      maxWidth(`px(848)),
      media(Theme.MediaQuery.notMobile, [height(`percent(110.))]),
    ]);
};

[@react.component]
let make = () => {
  <div className=Styles.singleRowBackground>
    <Wrapped>
      <div className=Styles.container>
        <img src="/static/img/NodeOpsTestnet.png" className=Styles.image />
        <div className=Styles.contentBlock>
          <div className=Styles.copyText>
            <h2 className=Styles.title> {React.string("Testnet")} </h2>
            <p className=Styles.description>
              {React.string(
                 "Check out what's in beta, take on Testnet challenges and earn Testnet points.",
               )}
            </p>
          </div>
          <div className=Css.(style([marginTop(`rem(1.))]))>
            <Button bgColor=Theme.Colors.orange dark=true>
              <span className=Styles.buttonText>
                {React.string("Go To Testnet")}
                <span className=Css.(style([marginTop(`rem(0.8))]))>
                  <Icon kind=Icon.ArrowRightSmall currentColor="white" />
                </span>
              </span>
            </Button>
          </div>
        </div>
      </div>
    </Wrapped>
  </div>;
};
