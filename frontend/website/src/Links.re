module Named = {
  type t = {
    link: string,
    name: string,
  };
};
open Named;

module Forms = {
  let mailingList = "https://docs.google.com/forms/d/e/1FAIpQLSdChigoRhyZqg1RbaA6ODiqJ4q42cPpNbSH-koxXHjLwDeqDw/viewform?usp=pp_url&entry.2026041782=I+just+want+to+learn+more!";

  let developingWithCoda = "https://docs.google.com/forms/d/e/1FAIpQLSdChigoRhyZqg1RbaA6ODiqJ4q42cPpNbSH-koxXHjLwDeqDw/viewform?usp=pp_url&entry.2026041782=I+want+to+develop+cryptocurrency+applications+with+Coda";

  let participateInConsensus = "https://docs.google.com/forms/d/e/1FAIpQLSdChigoRhyZqg1RbaA6ODiqJ4q42cPpNbSH-koxXHjLwDeqDw/viewform?usp=pp_url&entry.2026041782=I+want+to+help+run+the+Coda+network+by+participating+in+consensus";

  let compressTheBlockchain = "https://docs.google.com/forms/d/e/1FAIpQLSdChigoRhyZqg1RbaA6ODiqJ4q42cPpNbSH-koxXHjLwDeqDw/viewform?usp=pp_url&entry.2026041782=I+want+to+earn+Coda+by+helping+compress+the+blockchain";

  let improveSnarkTech = "https://docs.google.com/forms/d/e/1FAIpQLSdChigoRhyZqg1RbaA6ODiqJ4q42cPpNbSH-koxXHjLwDeqDw/viewform?usp=pp_url&entry.2026041782=I%27m+interested+in+improving+the+SNARK+tech+underlying+Coda";
};

module Static = {
  let whitepaper = {
    name: "Read the Coda Whitepaper",
    link: "/static/coda-whitepaper-05-10-2018-0.pdf",
  };

  let snarkette = {
    name: "Snarkette: JavaScript Groth-Maller SNARK verifier",
    link: "https://github.com/o1-labs/snarkette",
  };
};

module ThirdParty = {
  let testnetStatus = "https://status.codaprotocol.com/";

  let coindeskTossesBlocks = {
    name: "Coindesk: This Blockchain Tosses Blocks",
    link: "https://www.coindesk.com/blockchain-tosses-blocks-naval-metastable-back-twist-crypto-cash/",
  };
  let tokenDailyQA = {
    name: "TokenDaily: Deep Dive with O(1) on Coda Protocol",
    link: "https://www.tokendaily.co/p/q-as-with-o-1-on-coda-protocol",
  };

  let codaMediumPost = {
    name: "Coda: Keeping Cryptocurrency Decentralized",
    link: "https://medium.com/codaprotocol/coda-keeping-cryptocurrency-decentralized-e4b180721f42",
  };
  let codaTheSizeOfTweets = {
    name: "Coda: A Blockchain the Size of a Few Tweets",
    link: "https://hackernoon.com/a-blockchain-the-size-of-a-few-tweets-9db820eb6b29",
  };
};

module Talks = {
  let notesFromSnarkomicon = {
    name: "SNARKonomicon: Effectively program SNARKs",
    link: "https://www.youtube.com/watch?v=0u0XNfK8AJM",
  };
  let snarkyAlgebraicEffects = {
    name: "Snarky: Algebraic effects in Coda",
    link: "https://www.youtube.com/watch?v=Na2i8MbXbI",
  };

  let usingZkConstantSize = {
    name: "Using zk-SNARKs For A Constant Sized Blockchain",
    link: "https://www.youtube.com/watch?v=rZqaJaTOrio",
  };

  let scanningForScans = {
    name: "Fast Accumulation on Streams",
    link: "https://www.youtube.com/watch?v=YSnQ8N760mI",
  };

  let highThroughputSlowSnarks = {
    name: "High Throughput Slow SNARKs",
    link: "https://www.youtube.com/watch?v=NZmq1V-Te0E",
  };

  let zkSnarksSuccinctBlockchain = {
    name: "Using zk-SNARKs to create a succinct blockchain",
    link: "https://www.youtube.com/watch?v=7ST9VVA_Udg",
  };

  let hackSummit2018 = {
    name: "Hack Summit 2018: Coda Talk",
    link: "https://www.youtube.com/watch?v=eWVGATxEB6M",
  };

  let highLevelLanguage = {
    name: "A High-Level Language for Verifiable Computation",
    link: "https://www.youtube.com/watch?v=gYn6mTwJriw",
  };

  let snarkyDsl = {
    name: "Snarky, a DSL for Writing SNARKs",
    link: "https://www.youtube.com/watch?v=h0PUVR0s6Vg",
  };
};

module Podcasts = {
  let decentralizationTrojanHorse = {
    name: "Decentralization's Trojan Horse: CODA Protocol",
    link: "https://blog.sendwyre.com/decentralizations-trojan-horse-coda-protocol-with-evan-shapiro-co-founder-and-ceo-40eae1797ef8",
  };

  let digIntoRecursive = {
    name: "Digging into recursive zkSNARKs with Coda",
    link: "https://www.zeroknowledge.fm/54",
  };

  let tokenTalksInterview = {
    name: "Token Talks - Interview with Coda",
    link: "https://simplecast.com/s/17ed0e8d",
  };

  let codaSuccinctBlockchain = {
    name: "Coda: A Succinct Blockchain",
    link: "https://epicenter.tv/episode/243/",
  };
};

module Panel = {
  let zkProofsMindBending = {
    name: "Zero Knowledge Proofs: Mind Bending Tech",
    link: "https://youtu.be/NmnnO8lPssE",
  };

  let cryptographyCurrency = {
    name: "Crypto{graphy,currency} Meetup @ Coda HQ",
    link: "https://www.youtube.com/watch?v=gwW46u8Wqwg",
  };

  let scalarCapitalSummit = {
    name: "Scalar Capital Summit 2018",
    link: "https://www.youtube.com/watch?v=PgurOsSZ8OQ",
  };
};
