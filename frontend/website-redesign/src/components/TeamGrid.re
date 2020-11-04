module Styles = {
  open Css;
  let grid =
    style([
      display(`grid),
      paddingTop(`rem(1.)),
      gridTemplateColumns([`rem(10.), `rem(10.)]),
      gridAutoRows(`rem(17.3)),
      gridColumnGap(`rem(1.)),
      gridRowGap(`rem(1.)),
      media(
        Theme.MediaQuery.tablet,
        [
          gridTemplateColumns([
            `rem(10.),
            `rem(10.),
            `rem(10.),
            `rem(10.),
          ]),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          gridTemplateColumns([
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
          ]),
        ],
      ),
    ]);
};

[@react.component]
let make = (~switchModalState) => {
  <div className=Styles.grid>
    <TeamMember
      fullName="Evan Shapiro"
      title="CEO, O(1) Labs"
      src="/static/img/headshots/EvanShapiro.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Izaak Meckler"
      title="CTO, O(1) Labs"
      src="/static/img/headshots/IzaakMeckler.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Brandon Kase"
      title="Head of Product Engineering, O(1) Labs"
      src="/static/img/headshots/BrandonKase.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Claire Kart"
      title="Head of Marketing & Community, O(1) Labs"
      src="/static/img/headshots/ClaireKart.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Emre Tekisalp"
      title="Head of Business Development, O(1) Labs"
      src="/static/img/headshots/EmreTekisalp.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Bijan Shahrokhi"
      title="Head of Product, O(1) Labs"
      src="/static/img/headshots/BijanShahrokhi.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Aneesha Raines"
      title="Engineering Manager, O(1) Labs"
      src="/static/img/headshots/AneeshaRaines.jpeg"
      switchModalState
    />
    <TeamMember
      fullName="Sherry Lin"
      title="Marketing Manager, O(1) Labs"
      src="/static/img/headshots/SherryLin.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Carey Janecka"
      title="Product Engineer, O(1) Labs"
      src="/static/img/headshots/CareyJanecka.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Kate El-Bizri"
      title="Visual Designer,  O(1) Labs"
      src="/static/img/headshots/KateElBizri2.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Deepthi Kumar"
      title="Protocol Engineer,  O(1) Labs"
      src="/static/img/headshots/DeepthiKumar.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Paul Steckler"
      title="Protocol Engineer,   O(1) Labs"
      src="/static/img/headshots/PaulSteckler.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Jiawei Tang"
      title="Protocol Engineer,  O(1) Labs"
      src="/static/img/headshots/JiaweiTang.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Nathan Holland"
      title="Protocol Engineer,  O(1) Labs"
      src="/static/img/headshots/NathanHolland.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Matthew Ryan"
      title="Protocol Engineer,  O(1) Labs"
      src="/static/img/headshots/MatthewRyan.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Ahmad Wilson"
      title="Protocol Reliability Engineer, O(1) Labs"
      src="/static/img/headshots/AhmadWilson.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Vanishree Rao"
      title="Protocol Researcher, O(1) Labs"
      src="/static/img/headshots/VanishreeRao.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Michelle Wong"
      title="Product Engineer, O(1) Labs"
      src="/static/img/headshots/MichelleWong.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Nacera Rodstein"
      title="Operations Associate, O(1) Labs"
      src="/static/img/headshots/NaceraRodstein.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Christine Yip"
      title="Community Manager, O(1) Labs"
      src="/static/img/headshots/ChristineYip.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Andrew Trainor"
      title="Protocol Engineer, O(1) Labs"
      src="/static/img/headshots/AndrewTrainor.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Helena Li"
      title="Protocol Engineer, O(1) Labs"
      src="/static/img/headshots/HelenaLi.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Chris Pryor"
      title="Lead Product Designer, O(1) Labs"
      src="/static/img/headshots/ChrisPryor.jpg"
      switchModalState
    />
    <TeamMember
      fullName="Joon Kim"
      title="General Counsel, O(1) Labs"
      src="/static/img/headshots/JoonKim.jpg"
      switchModalState
    />
  </div>;
};
