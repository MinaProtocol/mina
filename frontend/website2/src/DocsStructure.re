type t =
  | Page(string, string)
  | Folder(string, array(t));

let structure = [|
  Page("Overview", ""),
  Page("Getting Started", "getting-started"),
  Page("My First Transaction", "my-first-transaction"),
  Page("Become a Node Operator", "node-operator"),
  Page("Contributing to Coda", "contributing"),
  Folder(
    "Developers",
    [|
      Page("Developers Overview", "developers/"),
      Page("Codebase Overview", "developers/codebase-overview"),
      Page("Repository Structure", "developers/directory-structure"),
      Page("Code Reviews", "developers/code-reviews"),
      Page("Style Guide", "developers/style-guide"),
      Page("GraphQL API", "developers/graphql-api"),
    |],
  ),
  Folder(
    "Coda Protocol Architecture",
    [|
      Page("Coda Overview", "architecture/"),
      Page("Lifecycle of a Payment", "architecture/lifecycle-payment"),
      Page("Consensus", "architecture/consensus"),
      Page("Proof of Stake", "architecture/proof-of-stake"),
    |],
  ),
  Folder(
    "SNARKs",
    [|
      Page("SNARKs Overview", "snarks/"),
      Page("Getting started using SNARKs", "snarks/snarky"),
      Page("Which SNARK is right for me?", "snarks/constructions"),
      Page("The snarkyjs-crypto library", "snarks/snarkyjs-crypto"),
      Page("The snarky-universe library", "snarks/snarky-universe"),
    |],
  ),
  Page("GUI Wallet", "gui-wallet"),
  Page("CLI Reference", "cli-reference"),
  Page("Troubleshooting", "troubleshooting"),
  Page("FAQ", "faq"),
  Page("Glossary", "glossary"),
|];
