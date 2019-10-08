module Cdn = {
  module Crypto = {
    type t;
    [@bs.val] [@bs.module "crypto"]
    external createHash: string => t = "createHash";
    [@bs.send] external update: (t, string) => unit = "update";
    [@bs.send] external digest: (t, string) => string = "digest";
  };

  let prefix = ref(None);

  let setPrefix = p => prefix := Some(p);

  let prefix = () =>
    switch (prefix^) {
    | None =>
      Js.Exn.raiseError(
        "CDN Prefix unset -- Can't run Links.Cdn.url at the top level.",
      )
    | Some(prefix) => prefix
    };

  let cache = Hashtbl.create(20);

  let localAssetPath = path =>
    if (path.[0] == '/') {
      "." ++ path;
    } else {
      prerr_endline({j|"Expected cdn path `$path` to begin with /"|j});
      exit(1);
    };

  let getHashedPath = path => {
    if (!Hashtbl.mem(cache, path)) {
      let localPath = localAssetPath(path);
      // Get file contents
      let content = Node.Fs.readFileAsUtf8Sync(localPath);
      // Generate hash of file
      let hashGen = Crypto.createHash("sha256");
      Crypto.update(hashGen, content);
      let hash = Crypto.digest(hashGen, "hex");
      let index = Js.String.lastIndexOf(".", path);
      let newPath =
        String.sub(path, 0, index)
        ++ "-"
        ++ hash
        ++ String.sub(path, index, String.length(path) - index);
      Hashtbl.add(cache, path, newPath);
    };
    Hashtbl.find(cache, path);
  };

  let url = path => prefix() ++ getHashedPath(path);
};

module Named = {
  type t('a) = {
    link: string,
    name: 'a,
  };
};

open Named;

module Forms = {
  let mailingList = {
    link: "https://docs.google.com/forms/d/e/1FAIpQLSdChigoRhyZqg1RbaA6ODiqJ4q42cPpNbSH-koxXHjLwDeqDw/viewform?usp=pp_url&entry.2026041782=I+just+want+to+learn+more!",
    name: "mailinglist-none",
  };

  let developingWithCoda = {
    link: "https://docs.google.com/forms/d/e/1FAIpQLSdChigoRhyZqg1RbaA6ODiqJ4q42cPpNbSH-koxXHjLwDeqDw/viewform?usp=pp_url&entry.2026041782=I+want+to+develop+cryptocurrency+applications+with+Coda",
    name: "mailinglist-developingwithcoda",
  };

  let participateInConsensus = {
    link: "https://docs.google.com/forms/d/e/1FAIpQLScQRGW0-xGattPmr5oT-yRb9aCkPE6yIKXSfw1LRmNx1oh6AA/viewform?usp=sf_link",
    name: "mailinglist-participateinconsensus",
  };

  let compressTheBlockchain = {
    link: "https://docs.google.com/forms/d/e/1FAIpQLSdChigoRhyZqg1RbaA6ODiqJ4q42cPpNbSH-koxXHjLwDeqDw/viewform?usp=pp_url&entry.2026041782=I+want+help+run+the+Coda+network+by+compressing+the+blockchain",
    name: "mailinglist-compresstheblockchain",
  };

  let improveSnarkTech = {
    link: "https://docs.google.com/forms/d/e/1FAIpQLSdChigoRhyZqg1RbaA6ODiqJ4q42cPpNbSH-koxXHjLwDeqDw/viewform?usp=pp_url&entry.2026041782=I%27m+interested+in+improving+the+SNARK+tech+underlying+Coda",
    name: "mailinglist-improvesnarktech",
  };
};

module Static = {
  let whitepaper = () => {
    name: ("Read the Coda Whitepaper", "coda-whitepaper"),
    // Hardcoding to v2 as the pdf is no longer tracked in git
    link: "https://cdn.codaprotocol.com/v2/static/coda-whitepaper-05-10-2018-0.pdf",
  };

  let modifiedsnark = () => {
    name: (
      "Read about the zkSNARK construction we're using",
      "modified-BG-snark",
    ),
    link: Cdn.url("/static/modified-BG-snark-05-03-2019-0.pdf"),
  };

  let snarkette = {
    name: ("Snarkette: JavaScript Groth-Maller SNARK verifier", "snarkette"),
    link: "https://github.com/o1-labs/snarkette",
  };
};

module ThirdParty = {
  let testnetStatus = "https://status.codaprotocol.com/";

  let coindeskStartupBlockchain = {
    name: (
      "Coindesk: Startup Behind Disappearing Blockchain",
      "coindesk-startup-blockchain",
    ),
    link: "https://www.coindesk.com/coinbase-paradigm-invest-15-million-in-startup-behind-disappearing-blockchain",
  };

  let coindeskTossesBlocks = {
    name: (
      "Coindesk: This Blockchain Tosses Blocks",
      "coindesk-tosses-blocks",
    ),
    link: "https://www.coindesk.com/blockchain-tosses-blocks-naval-metastable-back-twist-crypto-cash/",
  };
  let tokenDailyQA = {
    name: (
      "TokenDaily: Deep Dive with O(1) on Coda Protocol",
      "tokendaily-deepdive",
    ),
    link: "https://www.tokendaily.co/p/q-as-with-o-1-on-coda-protocol",
  };

  let codaMediumPost = {
    name: (
      "Coda: Keeping Cryptocurrency Decentralized",
      "coda-cryptocurrency-decentralized",
    ),
    link: "https://medium.com/codaprotocol/coda-keeping-cryptocurrency-decentralized-e4b180721f42",
  };
  let codaTheSizeOfTweets = {
    name: (
      "Coda: A Blockchain the Size of a Few Tweets",
      "coda-blockchain-size-of-few-tweets",
    ),
    link: "https://hackernoon.com/a-blockchain-the-size-of-a-few-tweets-9db820eb6b29",
  };
};

module Talks = {
  let notesFromSnarkomicon = {
    name: ("SNARKonomicon: Effectively program SNARKs", "snarkominomicon"),
    link: "https://www.youtube.com/watch?v=0u0XNfK8AJM",
  };
  let snarkyAlgebraicEffects = {
    name: ("Snarky: Algebraic effects in Coda", "snarky-algebraic-effects"),
    link: "https://www.youtube.com/watch?v=-Na2i8MbXbI",
  };

  let usingZkConstantSize = {
    name: (
      "Using zk-SNARKs For A Constant Sized Blockchain",
      "using-zk-snarks",
    ),
    link: "https://www.youtube.com/watch?v=rZqaJaTOrio",
  };

  let scanningForScans = {
    name: ("Fast Accumulation on Streams", "fast-accumulation-on-streams"),
    link: "https://www.youtube.com/watch?v=YSnQ8N760mI",
  };

  let highThroughputSlowSnarks = {
    name: ("High Throughput Slow SNARKs", "high-throughput-slow-snarks"),
    link: "https://www.youtube.com/watch?v=NZmq1V-Te0E",
  };

  let zkSnarksSuccinctBlockchain = {
    name: (
      "Using zk-SNARKs to create a succinct blockchain",
      "zksnarks-succinct-blockchain",
    ),
    link: "https://www.youtube.com/watch?v=7ST9VVA_Udg",
  };

  let hackSummit2018 = {
    name: ("Hack Summit 2018: Coda Talk", "hack-summit-2018"),
    link: "https://www.youtube.com/watch?v=eWVGATxEB6M",
  };

  let highLevelLanguage = {
    name: (
      "A High-Level Language for Verifiable Computation",
      "high-level-language",
    ),
    link: "https://www.youtube.com/watch?v=gYn6mTwJriw",
  };

  let snarkyDsl = {
    name: ("Snarky, a DSL for Writing SNARKs", "snarky-dsl-for-snarks"),
    link: "https://www.youtube.com/watch?v=h0PUVR0s6Vg",
  };
};

module Podcasts = {
  let decentralizationTrojanHorse = {
    name: ("Decentralization's Trojan Horse: CODA Protocol", "trojan-horse"),
    link: "https://blog.sendwyre.com/decentralizations-trojan-horse-coda-protocol-with-evan-shapiro-co-founder-and-ceo-40eae1797ef8",
  };

  let digIntoRecursive = {
    name: (
      "Digging into recursive zkSNARKs with Coda",
      "digging-into-snarks",
    ),
    link: "https://www.zeroknowledge.fm/54",
  };

  let tokenTalksInterview = {
    name: ("Token Talks - Interview with Coda", "token-talks-interview-0"),
    link: "https://simplecast.com/s/17ed0e8d",
  };

  let codaSuccinctBlockchain = {
    name: ("Coda: A Succinct Blockchain", "epicenter-succinct-blockchain"),
    link: "https://epicenter.tv/episode/243/",
  };
};

module Panel = {
  let zkProofsMindBending = {
    name: ("Zero Knowledge Proofs: Mind Bending Tech", "panel-zkproofs"),
    link: "https://youtu.be/NmnnO8lPssE",
  };

  let cryptographyCurrency = {
    name: (
      "Crypto{graphy,currency} Meetup @ Coda HQ",
      "panel-crypgraphycurrency",
    ),
    link: "https://www.youtube.com/watch?v=gwW46u8Wqwg",
  };

  let scalarCapitalSummit = {
    name: ("Scalar Capital Summit 2018", "panel-scalar-capital-2018"),
    link: "https://www.youtube.com/watch?v=PgurOsSZ8OQ",
  };
};

module Lists = {
  let articles = posts => {
    let render_post = (name, title) => {
      name: title,
      link: "/blog/" ++ name ++ ".html",
    };
    let ((name, _, title), ps) = (List.hd(posts), List.tl(posts));
    [
      render_post(name, title),
      Static.whitepaper(),
      ThirdParty.coindeskStartupBlockchain,
      ThirdParty.codaMediumPost,
      ThirdParty.tokenDailyQA,
      Static.modifiedsnark(),
    ]
    // top 5 above, rest below the fold
    @ List.map(
        ((name, _, title)) =>
          {name: title, link: "/blog/" ++ name ++ ".html"},
        ps,
      )
    // after the blog posts
    @ [
      Static.snarkette,
      ThirdParty.codaTheSizeOfTweets,
      ThirdParty.coindeskTossesBlocks,
    ];
  };

  let richMedia = [
    Talks.hackSummit2018,
    Podcasts.tokenTalksInterview,
    Talks.highLevelLanguage,
    Podcasts.digIntoRecursive,
    Podcasts.decentralizationTrojanHorse,
    // top 5 above, rest below the fold
    Talks.notesFromSnarkomicon,
    Panel.cryptographyCurrency,
    Talks.snarkyAlgebraicEffects,
    Talks.usingZkConstantSize,
    Panel.zkProofsMindBending,
    Talks.scanningForScans,
    Panel.scalarCapitalSummit,
    Talks.highThroughputSlowSnarks,
    Talks.zkSnarksSuccinctBlockchain,
    Talks.snarkyDsl,
  ];
};
