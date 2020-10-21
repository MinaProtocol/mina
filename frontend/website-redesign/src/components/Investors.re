module Styles = {
  open Css;
  let backgroundImage =
    style([
      backgroundSize(`cover),
      backgroundImage(url("/static/img/InvestorsBackgroundMobile.jpg")),
      media(
        Theme.MediaQuery.tablet,
        [backgroundImage(url("/static/img/InvestorsBackgroundTablet.jpg"))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          height(`rem(100.)),
          backgroundImage(url("/static/img/InvestorsBackgroundDesktop.jpg")),
        ],
      ),
    ]);
  let investorGrid =
    style([
      display(`grid),
      gridTemplateColumns([`rem(10.), `rem(10.)]),
      gridAutoRows(`rem(5.5)),
      gridGap(`rem(1.)),
      selector("div, img", [height(`rem(5.5)), width(`rem(10.))]),
      media(
        Theme.MediaQuery.tablet,
        [gridTemplateColumns([`repeat((`num(4), `rem(10.)))])],
      ),
      media(
        Theme.MediaQuery.desktop,
        [gridTemplateColumns([`repeat((`num(6), `rem(10.)))])],
      ),
    ]);

  let header = merge([Theme.Type.h2, style([marginBottom(`rem(0.5))])]);
  let subhead =
    merge([Theme.Type.sectionSubhead, style([marginBottom(`rem(4.))])]);
  let investorGridItem =
    style([
      Theme.Typeface.monumentGroteskMono,
      fontSize(`rem(1.125)),
      textAlign(`center),
      background(white),
      display(`flex),
      alignItems(`center),
      justifyContent(`center),
      padding2(~v=`rem(1.5), ~h=`rem(1.)),
    ]);
  let investorGridItemLarge =
    style([
      Theme.Typeface.monumentGroteskMono,
      fontSize(`rem(1.125)),
      textAlign(`center),
      background(white),
      display(`flex),
      alignItems(`center),
      justifyContent(`center),
      padding2(~v=`rem(1.5), ~h=`rem(1.)),
    ]);
  let rule = style([marginTop(`rem(3.))]);
  let advisorGrid =
    style([
      display(`grid),
      gridTemplateColumns([`repeat((`num(2), `rem(11.)))]),
      gridAutoRows(`rem(17.3)),
      gridColumnGap(`rem(1.)),
      media(
        Theme.MediaQuery.tablet,
        [gridTemplateColumns([`repeat((`num(4), `rem(11.)))])],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          gridTemplateColumns([`repeat((`num(6), `rem(11.)))]),
          marginBottom(`rem(7.)),
        ],
      ),
    ]);
  let advisors =
    merge([
      Theme.Type.h2,
      style([marginTop(`rem(2.)), marginBottom(`rem(0.5))]),
    ]);
  let advisorsSubhead =
    merge([Theme.Type.sectionSubhead, style([marginBottom(`rem(2.))])]);
};

[@react.component]
let make = () => {
  <>
    <div className=Styles.backgroundImage>
      <Wrapped>
        <Spacer height=7. />
        <h2 className=Styles.header> {React.string("Investors")} </h2>
        <p className=Styles.advisorsSubhead>
          {React.string("Supporting O(1) Labs")}
        </p>
        <div className=Styles.investorGrid>
          <img src="/static/img/logos/LogoAccomplice.png" />
          <div className=Styles.investorGridItemLarge>
            {React.string("Andrew Keys")}
          </div>
          <img src="/static/img/logos/LogoBlockchange.png" />
          <div className=Styles.investorGridItemLarge>
            {React.string("Charlie Noyes")}
          </div>
          <img src="/static/img/logos/LogoCoinbaseVentures.png" />
          <img src="/static/img/logos/LogoCollaborativeFund.png" />
          <img src="/static/img/logos/LogoCuriousEndeavors.png" />
          <img src="/static/img/logos/LogoDekryptCapital.png" />
          <img src="/static/img/logos/LogoDragonfly.png" />
          <div className=Styles.investorGridItem>
            {React.string("Ed Roman")}
          </div>
          <div className=Styles.investorGridItem>
            {React.string("Elad Gil")}
          </div>
          <img src="/static/img/logos/LogoElectricCapital.png" />
          <img src="/static/img/logos/LogoEvolveVC.png" />
          <div className=Styles.investorGridItem>
            {React.string("Fred Ehrsam")}
          </div>
          <img src="/static/img/logos/LogoGeneralCatalyst.png" />
          <div className=Styles.investorGridItemLarge>
            {React.string("Jack Herrick")}
          </div>
          <img src="/static/img/logos/LogoKilowattCapital.png" />
          <img src="/static/img/logos/LogoKindredVentures.png" />
          <img src="/static/img/logos/LogoLibertusCapital.png" />
          <div className=Styles.investorGridItem>
            {React.string("Linda Xie")}
          </div>
          <img src="/static/img/logos/LogoMetastable.png" />
          <img src="/static/img/logos/LogoMulticoinCapital.png" />
          <div className=Styles.investorGridItemLarge>
            {React.string("Naval Ravikant")}
          </div>
          <img src="/static/img/logos/LogoNimaCapital.png" />
          <img src="/static/img/logos/LogoParadigm.png" />
          <img src="/static/img/logos/LogoPolychainCapital.png" />
          <img src="/static/img/logos/LogoScifiVC.png" />
        </div>
        <div className=Styles.rule> <Rule color=Theme.Colors.black /> </div>
        <h2 className=Styles.advisors> {React.string("Advisors")} </h2>
        <p className=Styles.advisorsSubhead>
          {React.string("Supporting O(1) Labs")}
        </p>
        <div className=Styles.advisorGrid>
          // all images are placeholder for now

            <TeamMember
              fullName="Jill Carlson"
              title="Co-founder, Open Money Initiative"
              src="/static/img/headshots/carlson.jpg"
            />
            <TeamMember
              fullName="Paul Davidson"
              title="Co-founder & CEO, Alpha Exploration Co."
              src="/static/img/headshots/davidson.jpg"
            />
            <TeamMember
              fullName="Joseph Bonneau"
              title="Advisor"
              src="/static/img/headshots/bonneau.jpg"
            />
            <TeamMember
              fullName="Akis Kattis"
              title="Advisor"
              src="/static/img/headshots/kattis.jpg"
            />
            <TeamMember
              fullName="Benedikt Bunz"
              title="Advisor"
              src="/static/img/headshots/bunz.jpg"
            />
            <TeamMember
              fullName="Amit Sahai"
              title="Director, Center for Encrypted Functionalities"
              src="/static/img/headshots/sahai.jpg"
            />
          </div>
        <Spacer height=7. />
      </Wrapped>
    </div>
  </>;
};
