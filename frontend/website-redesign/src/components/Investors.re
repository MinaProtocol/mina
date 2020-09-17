module Styles = {
  open Css;
  let backgroundImage =
    style([
      backgroundSize(`cover),
      backgroundImage(url("/static/img/InvestorsBackgroundMobile.png")),
      media(
        Theme.MediaQuery.tablet,
        [backgroundImage(url("/static/img/InvestorsBackgroundTablet.png"))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          backgroundImage(url("/static/img/InvestorsBackgroundDesktop.png")),
        ],
      ),
    ]);
  let investorGrid =
    style([
      display(`grid),
      gridTemplateColumns([`rem(10.), `rem(10.)]),
      gridAutoRows(`rem(5.5)),
      gridColumnGap(`rem(1.)),
      gridRowGap(`rem(1.)),
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
        [padding2(~v=`rem(7.), ~h=`rem(9.5)), maxWidth(`rem(84.))],
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
      padding2(~v=`rem(2.), ~h=`rem(1.)),
    ]);
    let investorGridItemLarge =
    style([
      Theme.Typeface.monumentGroteskMono,
      fontSize(`rem(1.125)),
      textAlign(`center),
      background(white),
      padding2(~v=`rem(1.5), ~h=`rem(1.)),
    ]);
  let rule = style([media(Theme.MediaQuery.desktop, [marginTop(`rem(7.93))])]);
  let advisorGrid = style([display(`grid), gridColumnGap(`rem(1.)), gridTemplateColumns([`repeat(`num(2),`rem(10.))]), gridAutoRows(`rem(17.3))])
};

[@react.component]
let make = () => {
  <div className=Styles.backgroundImage>
    <div className=Styles.innerContainer>
      <h2 className=Styles.header> {React.string("Investors")} </h2>
      <p className=Styles.subhead> {React.string("Supporting O(1) Labs")} </p>
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
      <div className=Styles.rule>

      <Rule color=Theme.Colors.black/>
      </div>
      
        <h2 className=Theme.Type.h2> {React.string("Advisors")} </h2>
        <p className=Theme.Type.sectionSubhead>
          {React.string(
             "Supporting O(1) Labs",
           )}
        </p>

    <div className=Styles.advisorGrid>
      <TeamMember
        fullName="Jill Carlson"
        title="Co-founder, Open Money Initiative"
        src="/static/img/headshots/EvanShapiro.jpg"
      />
      <TeamMember
        fullName="Paul Davidson"
        title="CTO, O(1) Labs"
        src="/static/img/headshots/IzaakMeckler.jpg"
      />
      <TeamMember
        fullName="Joseph Bonneau"
        title="Head of Product Engineering, O(1) Labs"
        src="/static/img/headshots/BrandonKase.jpg"
      />
      <TeamMember
        fullName="Akis Kattis"
        title="Head of Marketing & Community, O(1) Labs"
        src="/static/img/headshots/ClaireKart.jpg"
      />
      <TeamMember
        fullName="Benedikt Bunz"
        title="Head of Marketing & Community, O(1) Labs"
        src="/static/img/headshots/ClaireKart.jpg"
      />
    </div>
        <Rule color=Theme.Colors.black />
      
    </div>
  </div>;
};
