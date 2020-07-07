module Member = {
  [@react.component]
  let make = (~name, ~title, ~description, ~imageName=?) => {
    let lastName = Js.String.split(" ", name)[1];
    let imageSrc =
      "/static/img/"
      ++ (
        switch (imageName) {
        | Some(imageName) => imageName
        | _ => String.lowercase_ascii(lastName)
        }
      )
      ++ ".jpg";
    <div
      className=Css.(
        merge([
          Theme.Technical.border(Css.border),
          style([
            display(`flex),
            flexDirection(`column),
            width(`rem(20.5)),
            minWidth(`rem(20.5)),
            flexGrow(1.),
            maxWidth(`rem(23.75)),
            marginTop(`rem(1.5625)),
            marginBottom(`rem(1.5625)),
            marginLeft(`zero),
            marginRight(`zero),
            media(
              Theme.MediaQuery.notMobile,
              [
                minHeight(`rem(27.5)),
                marginLeft(`rem(1.5625)),
                marginRight(`rem(1.5625)),
                width(`percent(100.)),
              ],
            ),
          ]),
        ])
      )>
      <div
        className=Css.(
          merge([
            Theme.Technical.border(Css.borderBottom),
            style([
              display(`flex),
              flexDirection(`row),
              alignItems(`center),
            ]),
          ])
        )>
        <img
          className=Css.(
            style([
              maxWidth(`rem(5.5)),
              maxHeight(`rem(5.5)),
              height(`auto),
              width(`auto),
              unsafe("WebkitFilter", "grayscale(1)"),
              unsafe("filter", "grayscale(1)"),
              marginLeft(`rem(0.875)),
              marginTop(`rem(0.625)),
              marginBottom(`rem(0.625)),
              ...Theme.paddingX(`rem(1.)),
            ])
          )
          src=imageSrc
          alt={j|Portrait photo of $name.|j}
        />
        <div
          className=Css.(
            style([
              display(`flex),
              flexDirection(`column),
              alignItems(`flexStart),
              justifyContent(`flexStart),
            ])
          )>
          <div
            className=Css.(
              style([
                display(`flex),
                justifyContent(`center),
                alignItems(`center),
                backgroundColor(Theme.Colors.tealBlue),
                height(`rem(1.75)),
              ])
            )>
            <h3
              className=Css.(
                merge([
                  Theme.H3.Technical.title,
                  style([
                    marginTop(`rem(0.0625)),
                    // hack to remove top margin for IE11
                    media(
                      "all and (-ms-high-contrast: none), (-ms-high-contrast: active)",
                      [margin(`auto)],
                    ),
                    // hack to remove top margin for Edge
                    selector(
                      "@supports (-ms-ime-align:auto)",
                      [margin(`auto)],
                    ),
                    ...Theme.paddingX(`rem(0.1875)),
                  ]),
                ])
              )>
              {React.string(name)}
            </h3>
          </div>
          <h5
            className=Css.(
              merge([
                Theme.Technical.basic,
                style([
                  textAlign(`left),
                  whiteSpace(`nowrap),
                  marginTop(`rem(0.125)),
                ]),
              ])
            )>
            {React.string(title)}
          </h5>
        </div>
      </div>
      <p
        className=Css.(
          merge([
            style([
              marginLeft(`rem(1.875)),
              marginRight(`rem(2.)),
              ...Theme.paddingY(`rem(0.5)),
            ]),
            Theme.Body.Technical.basic,
          ])
        )>
        {React.string(description)}
      </p>
    </div>;
  };
};

module Section = {
  [@react.component]
  let make = (~name, ~children) => {
    let checkboxName = name ++ "-checkbox";
    let labelName = name ++ "-label";
    <div className=Css.(style([display(`flex), flexDirection(`column)]))>
      <h3 className=Theme.H3.Technical.boxed> {React.string(name)} </h3>
      <input
        type_="checkbox"
        id=checkboxName
        className=Css.(
          style([
            display(`none),
            selector(
              ":checked + div",
              [height(`auto), after([display(`none)])],
            ),
            selector(":checked ~ #" ++ labelName, [display(`none)]),
          ])
        )
      />
      <div
        className=Css.(
          style([
            position(`relative),
            height(`rem(45.)),
            overflow(`hidden),
            display(`flex),
            flexWrap(`wrap),
            marginLeft(`auto),
            marginRight(`auto),
            justifyContent(`center),
            after([
              contentRule(""),
              position(`absolute),
              bottom(`px(-1)),
              left(`zero),
              height(`rem(8.)),
              width(`percent(100.)),
              pointerEvents(`none),
              backgroundImage(
                `linearGradient((
                  `deg(0.),
                  [
                    (`zero, Theme.Colors.navyBlue),
                    (`percent(100.), Theme.Colors.navyBlueAlpha(0.0)),
                  ],
                )),
              ),
            ]),
          ])
        )>
        children
      </div>
      <label
        id=labelName
        className=Css.(
          merge([
            Theme.Link.basic,
            style([
              Theme.Typeface.pragmataPro,
              fontWeight(`bold),
              display(`block),
              height(`rem(4.)),
              width(`rem(20.)),
              marginLeft(`auto),
              marginRight(`auto),
              marginTop(`rem(1.0)),
              marginBottom(`rem(3.0)),
              textAlign(`center),
              cursor(`pointer),
            ]),
          ])
        )
        htmlFor=checkboxName>
        {React.string({js|View all ↓|js})}
      </label>
      <RunScript>
        {Printf.sprintf(
           {|document.getElementById("%s").checked = false;|},
           checkboxName,
         )}
      </RunScript>
    </div>;
  };
};

let advisor = "Advisor";
let headerHeight = `rem(6.125);
let headerStyle =
  Css.(
    style([
      lineHeight(headerHeight),
      color(Theme.Colors.white),
      Theme.Typeface.rubik,
      fontSize(`rem(2.1)),
      textAlign(`center),
      display(`inlineBlock),
      media(Theme.MediaQuery.notMobile, [fontSize(`rem(2.8))]),
    ])
  );
[@react.component]
let make = () => {
  <>
    <div
      className=Css.(
        style([
          transforms([`translateY(`percent(-50.0))]),
          height(headerHeight),
          marginLeft(`auto),
          marginRight(`auto),
          marginBottom(`rem(3.0)),
          maxWidth(`rem(27.125)),
          backgroundColor(Theme.Colors.navyBlue),
          // TODO: How do you use the boxShadow in bs-css
          unsafe(
            "boxShadow",
            "0 2px 50px 0 rgba(0, 0, 0, 0.2), 0 7px 8px 0 rgba(0, 0, 0, 0.5)",
          ),
          textAlign(`center),
          whiteSpace(`nowrap),
        ])
      )>
      <span
        className=Css.(
          merge([
            headerStyle,
            style([fontWeight(`light), marginRight(`rem(1.))]),
          ])
        )>
        {React.string("Built by ")}
      </span>
      <span
        className=Css.(merge([headerStyle, style([fontWeight(`medium)])]))>
        {React.string(" O(1) Labs")}
      </span>
    </div>
    <Section name="Team">
      <Member
        name="Evan Shapiro"
        title="CEO"
        description="Evan Shapiro graduated from Carnegie Mellon with a BS in computer \
       science. He then obtained his research MS while working in the CMU \
       Personal Robotics Lab, where he did research for the HERB robotics \
       platform. He has also worked as a software engineer for Mozilla."
      />
      <Member
        name="Izaak Meckler"
        title="CTO"
        description="Izaak Meckler is a mathematician and computer scientist. Most \
       recently, he was a PhD student studying cryptography at UC Berkeley. \
       Prior to that, he worked as a software engineer at trading firm Jane \
       Street, and has contributed to numerous open source projects including \
       the Elm compiler."
      />
      <Member
        name="Brad Cohn"
        title="Strategy & Operations"
        description="Brad Cohn has diverse work experience, including stints in an \
       electrophysiology lab, high frequency trading firm, a technology think \
       tank, and a hedge fund. He most recently came from Bridgewater \
       Associates where he was an engineer on the currency team and Ray \
       Dalio's research team before joining a group of engineers dedicated to \
       rearchitecting core investment systems. He holds a BS in math from \
       UChicago with a minor in computational neuroscience."
      />
      <Member
        name="Brandon Kase"
        title="Head of Product Engineering"
        description="Brandon Kase loves functional programming. He was first introduced to \
       it while pursuing his BS in computer science at Carnegie Mellon. He \
       has worked as a software engineer for Highlight (acquired by \
       Pinterest), Pinterest, Facebook, and Mozilla. Brandon is excited about \
       the safety and clarity strong statically typed functional programming \
       techniques can bring to the software industry. He also enjoys \
       proselytizing, so you may find him speaking at a conference near you."
      />
      <Member
        name="Ember Arlynx"
        title="Protocol Engineer"
        description="Ember Arlynx is a seasoned open source contributor, recently \
         working primarily on the Rust compiler and libraries. They studied \
         computer science at Clarkson University and have worked at Dyn, \
         Mozilla, Leap Motion, and NICTA. They are especially interested in \
         formal verification, the seL4 microkernel, and what high powered \
         functional programming can do for trustworthy software."
      />
      <Member
        name="Deepthi Kumar"
        title="Protocol Engineer"
        description="Deepthi is a functional programming enthusiast and software engineer. \
       In her recently completed master's work, Deepthi designed GitQL, a \
       novel embedded DSL for querying textual changes in software \
       repositories. Her interests span programming languages and program \
       analysis. Deepthi holds an MS in computer science from Oregon State \
       University and a BE from Visvesvaraya Technological University."
      />
      <Member
        name="Nathan Holland"
        title="Protocol Engineer"
        description="Nathan is a passionate, self-taught programmer who loves programming \
       languages and paradigms and using high-level abstractions to create \
       high-performance systems. Some of his favorite projects have been \
       developing an array programming languages that targeted GPUs, an \
       Elixir DSL for service buses, a MySql binary log deserializer, and a \
       VR-based window manager on Linux. Most recently, Nathan was building a \
       unique educational program to teach people how to program from the \
       ground up using simplified programming languages and a simple virtual \
       machine."
      />
      <Member
        name="Nacera Rodstein"
        title="Operations Associate"
        description="Nacera has had a career spanning startups, medium sized companies, and \
              corporations. After earning her BS and MS from IAE in Lille, France, \
              Nacera moved to San Francisco. Over the next decade, she worked with \
              Bleacher Report (through growth from 10 to 60 employees and an \
              acquisition by Turner), Mokum Solutions, Sephora, Venture Beat, AMSI, \
              Oracle, and a software sales business which she helped start up and \
              scale."
      />
      <Member
        name="Paul Steckler"
        title="Protocol Engineer"
        description="Paul is a functional programmer and researcher. In the academic realm, \
       he's followed his interest in PLs, type systems, and formal \
       verification through collaborations with INRIA, the MIT PLV Group, and \
       NICTA. He also worked on the initial implementation of Alacris, a \
       cryptocurrency solution layered on top of existing blockchains. He \
       holds a PhD in computer science from Northeastern University."
      />
      <Member
        name="Harold Herbert"
        title="Head of Design"
        description="Harold previously designed brands, products, and experiences at Hired, \
             Flipboard, Zillow, and with a range of technology companies while \
             running an independent design studio. He believes that all design is \
             experience design. Regardless of the medium, the end goal is for the \
             well-being of the user."
      />
      <Member
        name="Vanishree Rao"
        title="Protocol Researcher"
        description="Vanishree is a theoretical and applied cryptographer with deep \
       experience in industry and academia. She earned her PhD at UCLA \
       through her work on zk-proofs, multiparty computation, hashing, and \
       pseudorandom functions, among other projects. She then worked in \
       industry at Xerox PARC and Intertrust Technologies. Vanishree enjoys \
       developing cryptographic solutions for real-world challenges and \
       communicating intuitive explanations of complex cryptography concepts."
      />
      <Member
        name="Matthew Ryan"
        title="Protocol Engineer"
        description="Matthew Ryan is a self-taught programmer with a strong interest in \
       computer-aided theorem proving, formal program verification, and \
       functional programming. He has been involved with several open-source \
       projects, and passionately believes in the open-source philosophy. He \
       has a BSc in Mathematics from the University of Warwick, U.K., where \
       he studied cryptography."
      />
      <Member
        name="Jiawei Tang"
        title="Protocol Engineer"
        description="Jiawei loves writing interpreters and type checkers. He received his \
       BS in computer science from Indiana University, and he's fascinated by \
       categorical semantics and dependent type theory. Currently, he is \
       implementing a toy dependently typed language called Pie."
      />
      <Member
        name="Carey Janecka"
        title="Product Engineer"
        description="Carey loves working on crazy ideas. He's designed and \
        built products for SpaceX, Coinbase and a variety of early-stage \
        companies. Nothing gets him more excited than working on simple user \
        interfaces for complex systems. He's excited for the applications that \
        can be built on top of Coda and enabling others to build cool things."
      />
      <Member
        name="Claire Kart"
        title="Head of Marketing & Community"
        description="Claire's career has focused on using technology to reimagine financial \
        services and building community to increase engagement and opportunities for individuals. \
        Prior to joining the team at O(1) Labs, she was at Ripple, where she led a number of \
        strategic projects and served as the main liaison to the XRP community. Prior to that, \
        Claire was an early employee at SoFi, were she was involved in the day-to-day operations \
        across all functions of the marketing team during four years of hyper growth, including \
        leading their member engagement strategy. Earlier in her career, she designed and \
        implemented a community-based micro grant program in rural India that has sponsored \
        300+ women to attend university. Originally from rural Pennsylvania, Claire graduated \
        with distinction from Dartmouth College (A.B.) and holds an MBA from the University \
        of Texas at Austin."
      />
      <Member
        name="Conner Swann"
        title="Protocol Reliability Eng"
        description="Conner is an infrastructure enthusiast with extensive \
          experience operating distributed systems at scale. His journey \
          through the technology sector has taken him from People Analytics \
          to Healthcare Tech and now to the Crypto space. He enjoys the challenge \
          of applying DevOps methodologies and tooling to emerging industries, and \
          looks forward to contributing back to the wider Open Source community. \
          Conner is a California Native and has a BSc in Computer Science from \
          Northern Arizona University."
      />
      <Member
        name={js|Emre Tekisalp|js}
        title="Head of Business Development"
        description="Emre's career has focused on bringing new economic \
        opportunities to societies using the power of technology. Before O(1) \
        Labs, he spent two years at Coinbase's Business Development team where \
        he led a number of strategic programs during a period when the company \
        grew 10x. Before Coinbase, Emre was a Product Manager at Intel's wearable \
        devices group. Originally from Istanbul, Turkey, Emre has an MBA degree \
        from Columbia University."
      />
      <Member
        name="Christine Yip"
        title="Community Manager"
        description="Christine is an early contributor in the community with broad \
        experience in multidisciplinary engineering teams. She previously worked for \
        global firms in the US, The Netherlands, Czech Republic, and Hong Kong. \
        She believes that we can take more ownership of our lives than ever before by \
        using blockchain technology. She supports the community and Coda by combining their \
        efforts in achieving a decentralized future."
      />
      <Member
        name="Michelle Wong"
        title="Product Engineer"
        description="Michelle believes that great products are built upon \
        empathy for the user and iterative processes. She recently graduated \
        from Smith College with a BA in Computer Science and is excited about \
        developing products that contribute to the evolution of decentralized technology. "
      />
      <Member
        name="Sherry Lin"
        title="Marketing Manager"
        description="Sherry is a marketing and communications professional who enjoys \
       telling stories that resonate. Her previous experiences have been in the hardware \
       (semiconductor) space, but she is really interested in how blockchain can solve problems \
       by disrupting the status quo. She is excited to work on developing blockchain technology \
       that will open up more opportunities to more people. Sherry holds a BA in Communications/International \
       Studies from Northwestern University."
      />
      <Member
        name="Kate El-Bizri"
        title="Visual Designer"
        description="In addition to a BFA in Visual Design, Kate has a Bachelor's degree in psychology. \
      Her philosophy is that understanding what motivates and drives our behaviors creates effective design systems.\
       Through both agency and in-house, she's worked with many companies from small startups to large-scale \
       Fortune 100 companies to communicate their stories to the world. She believes everyone is creative at heart, \
       and that creative inspiration can come from anywhere through engaging with the world around us."
      />
      <Member
        name="Ahmad Wilson"
        title="Protocol Reliability Eng"
        description="Ahmad is a computer scientist and self-proclaimed \"tech-head\" \
        interested in software infrastructure, user-interfaces and AI/automation. \
        He holds a MSc in HCI & AI from Brown University, and a BS in CS from Morehouse College. \
        He has developed software for startups and larger corporations such as Yelp and Microsoft for over a decade. \
        He's a fan of New England sports teams (Go Pats!), gardening, sci-fi and learning about \
         cryptocurrency and the future of the decentralized web."
      />
      <Member
        name="Bijan Shahrokhi"
        title="Product Manager"
        description="Bijan has been a product leader in the fintech industry for over 10 years and in blockchain for \
      over 5 years. Prior to joining O(1) Labs, Bijan was Head of Product at Harbor, a Layer 2 compliance protocol on Ethereum. "
      />
      <Member
        name="Aneesha Raines"
        title="Engineering Manager"
        description="
        Aneesha's career in software engineering has spanned a wide range of \
        technology companies from biotech startup to big enterprise.  \
        She has an MSE in computer engineering from the University of Michigan \
        and most recently came from an identity company as an Engineering Manager. \
        Her primary background is in QA, so believes in delivering high quality, scalable and maintainable software.  \
        She loves team building and working with individuals to achieve their goals."
      />
    </Section>
    <Section name="Advisors">
      <Member
        name="Jill Carlson"
        title=advisor
        description="Jill has worked with the IMF and is an advisor to cryptocurrency and blockchain-based ventures. \
        Previously, Jill ran strategy at blockchain start up Chain, where she managed \
        initiatives with Nasdaq and State Street. Jill has conducted academic research \
        on cryptocurrency at the University of Oxford, where she focused on the economic \
        and political implications of bitcoin. Jill began her career as a credit trader at Goldman Sachs. \
        She holds a MSc from Magdalen College, Oxford, and an AB from Harvard, where she studied Classics."
      />
      <Member
        name="Paul Davison"
        title=advisor
        description="Paul Davison is the CEO of CoinList - the leading platform for high \
       quality, compliant token sales and airdrops. Prior to CoinList, Paul \
       was the Founder/CEO of Highlight (acquired by Pinterest), an EIR at \
       Benchmark Capital, and a VP at Metaweb (acquired by Google). He holds \
       a BS from Stanford University and an MBA from Stanford Business School."
      />
      <Member
        name="Joseph Bonneau"
        title=advisor
        description="Joseph is an assistant professor at NYU. His research has spanned a \
        variety of topics in cryptography and security including HTTPS and web security, passwords \
        and authentication, cryptocurrencies, end-to-end encrypted communication tools, \
        and side-channel cryptanalysis. He is co-author of the popular textbook \"Bitcoin \
        and Cryptocurrency Technologies\" and co-taught the first MOOC on cryptocurrencies. \
        He holds a PhD from the University of Cambridge and BS and MS degrees in computer science \
        and cryptography from Stanford University."
      />
      <Member
        name="Akis Kattis"
        title=advisor
        description="Akis is a PhD candidate in Computer Science at NYU's Courant \
       Institute, where he is advised by Professors Joseph Bonneau and \
       Yevgenyi Dodis. His research revolves around cryptography, privacy, \
       and security, currently focusing on the privacy and scalability issues \
       affecting cryptocurrencies. He also works on differential privacy and \
       its applications to distributed systems and private learning. Akis \
       holds an MSc in theoretical computer science from the University of \
       Toronto and a BSE from Princeton University."
      />
      <Member
        name={js|Benedikt Bünz|js}
        title=advisor
        imageName="bunz"
        description="Benedikt is a PhD student in the Applied Crypto Group at Stanford and \
       he is advised by Dan Boneh. His research focuses on improving the \
       cryptography of cryptocurrencies. He has done research on zero \
       knowledge proofs (Bulletproofs), verifiable delay functions, super \
       light clients, confidential smart contracts and proofs of solvency."
      />
      <Member
        name="Amit Sahai"
        title=advisor
        description="Amit Sahai is a Professor of Computer Science at UCLA, Fellow of the ACM, and Fellow of the IACR. His research interests are in security, cryptography, and theoretical computer science. He is the co-inventor of Attribute-Based Encryption, Functional Encryption, Indistinguishability Obfuscation, author of over 100 technical research papers, and invited speaker at institutions such as MIT, Stanford, and Berkeley. He has also received honors from the Alfred P. Sloan Foundation, Okawa Foundation, Xerox Foundation, Google Research, the BSF, and the ACM. He earned his PhD in Computer Science from MIT and served on the faculty at Princeton before joining UCLA in 2004."
      />
    </Section>
  </>;
};
