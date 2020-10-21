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
  let innerContainer =
    style([
      padding2(~v=`rem(4.), ~h=`rem(1.25)),
      media(
        Theme.MediaQuery.tablet,
        [padding2(~v=`rem(4.), ~h=`rem(2.5))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          margin2(~v=`zero, ~h=`auto),
          padding2(~v=`rem(7.), ~h=`rem(9.5)),
          maxWidth(`rem(84.)),
        ],
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
  let rule =
    style([
      marginTop(`rem(2.)),
      media(Theme.MediaQuery.desktop, [marginTop(`rem(7.93))]),
    ]);
  let advisorGrid =
    style([
      display(`grid),
      gridTemplateColumns([`repeat((`num(2), `rem(10.)))]),
      gridAutoRows(`rem(17.3)),
      media(
        Theme.MediaQuery.tablet,
        [gridTemplateColumns([`repeat((`num(4), `rem(10.)))])],
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
  <div className=Styles.backgroundImage>
    <div className=Styles.innerContainer>
      <h2 className=Styles.header> {React.string("Investors")} </h2>
      <p className=Styles.advisorsSubhead>
        {React.string("Supporting O(1) Labs")}
      </p>
      <div className=Styles.investorGrid>
        <img src="/static/img/logos/LogoAccomplice.png" />
        <img src="/static/img/logos/Alternity 1.png" />
        <div className=Styles.investorGridItemLarge>
          {React.string("Andrew Keys")}
        </div>
        <img src="/static/img/logos/Bixin Ventures 1.png" />
        <img src="/static/img/logos/LogoBlockchange.png" />
        <div className=Styles.investorGridItemLarge>
          {React.string("Charlie Noyes")}
        </div>
        <img src="/static/img/logos/LogoCoinbaseVentures.png" />
        <img src="/static/img/logos/LogoCollaborativeFund.png" />
        <img src="/static/img/logos/LogoCuriousEndeavors.png" />
        <img src="/static/img/logos/LogoDekryptCapital.png" />
        <img src="/static/img/logos/Digital Asset Capital Mgmt 1.png" />
        <img src="/static/img/logos/DragonFly 1.png" />
        <div className=Styles.investorGridItem>
          {React.string("Ed Roman")}
        </div>
        <div className=Styles.investorGridItem>
          {React.string("Elad Gil")}
        </div>
        <img src="/static/img/logos/LogoElectricCapital.png" />
        <img src="/static/img/logos/LogoEvolveVC.png" />
        <img src="/static/img/logos/Fenbushi Capital  1.png" />
        <div className=Styles.investorGridItem>
          {React.string("Fred Ehrsam")}
        </div>
        <img src="/static/img/logos/LogoGeneralCatalyst.png" />
        <img src="/static/img/logos/Hashkey Capital 1.png" />
        <img src="/static/img/logos/IOSG Ventures 1.png" />
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
        <img src="/static/img/logos/NGC Ventures  1.png" />
        <img src="/static/img/logos/LogoNimaCapital.png" />
        <img src="/static/img/logos/LogoParadigm.png" />
        <img src="/static/img/logos/LogoPolychainCapital.png" />
        <img src="/static/img/logos/LogoScifiVC.png" />
        <img src="/static/img/logos/Signum Capital 1.png" />
        <img src="/static/img/logos/Skytale Capital 1.png" />
        <img src="/static/img/logos/Three Arrows Capital 1.png" />
        <img src="/static/img/logos/YBB Foundation 1.png" />
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
    </div>
  </div>;
};
