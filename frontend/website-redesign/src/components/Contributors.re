module Styles = {
  open Css;
  let container = style([margin2(~v=`rem(4.), ~h=`zero)]);

  let modalContainer = modalShowing =>
    style([
      modalShowing ? opacity(1.) : opacity(0.),
      modalShowing ? pointerEvents(`auto) : pointerEvents(`none),
      transition("opacity", ~duration=400, ~timingFunction=`easeIn),
      position(`fixed),
      height(`vh(100.)),
      width(`vw(100.)),
      backgroundColor(`rgba((0, 0, 0, 0.3))),
      display(`flex),
      top(`percent(50.)),
      left(`percent(50.)),
      transform(`translate((`percent(-50.), `percent(-50.)))),
      zIndex(2),
    ]);

  let modal = style([margin(`auto)]);
};

external asDomElement: 'a => Dom.element = "%identity";
[@react.component]
let make =
    (~profiles, ~genesisMembers, ~advisors, ~modalOpen, ~switchModalState) => {
  let (currentMemberIndex, setCurrentMemberIndex) = React.useState(_ => 0);
  let modalBackgroundRef = React.useRef(Js.Nullable.null);

  let allProfiles =
    profiles->Belt.Array.concat(genesisMembers)->Belt.Array.concat(advisors);

  let onPrevMemberPress = () => {
    currentMemberIndex <= 0
      ? () : setCurrentMemberIndex(_ => currentMemberIndex - 1);
  };

  let onNextMemberPress = () => {
    currentMemberIndex >= Array.length(allProfiles) - 1
      ? () : setCurrentMemberIndex(_ => currentMemberIndex + 1);
  };

  let closeModal = e => {
    modalBackgroundRef
    |> React.Ref.current
    |> Js.Nullable.toOption
    |> Option.iter(modalRef =>
         if (modalRef === asDomElement(ReactEvent.Mouse.target(e))
             && modalOpen) {
           switchModalState();
         }
       );
  };

  let setCurrentMember = (member: ContentType.GenericMember.t) => {
    let memberIndex =
      Belt.Array.getIndexBy(allProfiles, (m: ContentType.GenericMember.t) => {
        m.name == member.name
      });
    Belt.Option.mapWithDefault(memberIndex, (), index =>
      setCurrentMemberIndex(_ => index)
    );
  };

  <>
    <div
      className={Styles.modalContainer(modalOpen)}
      ref={modalBackgroundRef->ReactDOMRe.Ref.domRef}
      onClick={e => closeModal(e)}>
      <div className=Styles.modal>
        <ProfileCard
          member={Array.get(allProfiles, currentMemberIndex)}
          switchModalState
          onPrevMemberPress
          onNextMemberPress
        />
      </div>
    </div>
    <div className=Styles.container>
      <Wrapped>
        <Rule color=Theme.Colors.black />
        <TeamGrid profiles switchModalState setCurrentMember />
        <Rule color=Theme.Colors.black />
        <GenesisMembersGrid genesisMembers switchModalState setCurrentMember />
      </Wrapped>
    </div>
    <Investors advisors switchModalState setCurrentMember />
  </>;
};
