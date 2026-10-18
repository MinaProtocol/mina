// Check the values taken from a pull request comment before they are given to
// a build.
//
// Why this is needed
// ------------------
// The buildkite pipelines put these values straight into a dhall expression.
// mina-single-job runs:
//
//   dhall-to-yaml --quoted <<< "(./buildkite/src/Entrypoints/RunSingleJob.dhall) \
//     { name=\"${JOB_NAME}\" }" | buildkite-agent pipeline upload
//
// so the value ends up inside a dhall text literal. Dhall can read the
// environment: `env:BUILDKITE_AGENT_ACCESS_TOKEN` is a legal expression. A value
// that closes the quote can therefore run dhall of its own choosing on the
// agent, with the token of that agent within reach.
//
// Only a public member of the MinaProtocol organisation can start a build, so
// this is not open to anyone, but membership is a wide group and the check
// costs nothing.
//
// What is allowed
// ---------------
// A job name or a step pattern needs letters, digits and a few marks. It never
// needs a quotation mark, a backslash, a dollar or a backtick, and those are
// exactly what is needed to leave a dhall text literal or a shell string. So
// the rule is a list of what may appear, not a list of what may not: a mark
// that is forgotten then fails closed.
//
//   letters digits _ - . / * ? , and the space
//
// The star and the question mark are there because a selection is a pattern
// for step keys. The comma separates patterns.

// One value may not be longer than this. A real job name or selection is far
// shorter, and a long value in a comment is a sign of an attempt, not of use.
const MAX_LENGTH = 500;

const ALLOWED = /^[A-Za-z0-9_\-./*?, ]+$/;

// Report the characters that are not allowed, so the author is told what to
// change instead of only that it was refused.
const disallowedCharacters = (value) => {
  const bad = new Set();
  for (const character of value) {
    if (!ALLOWED.test(character)) {
      bad.add(character === "\n" ? "\\n" : character === "\t" ? "\\t" : character);
    }
  }
  return [...bad];
};

// Returns { value } when the input may be used, or { error } with a text for
// the author of the comment.
const checkArgument = (name, value) => {
  if (value === undefined || value === null || value === "") {
    return { error: `${name}: no value was given.` };
  }

  if (typeof value !== "string") {
    return { error: `${name}: the value must be text.` };
  }

  if (value.length > MAX_LENGTH) {
    return {
      error: `${name}: the value is longer than ${MAX_LENGTH} characters.`,
    };
  }

  if (!ALLOWED.test(value)) {
    const bad = disallowedCharacters(value);
    return {
      error:
        `${name}: these characters may not be used: ${bad.join(" ")}\n` +
        "Only letters, digits and _ - . / * ? , and the space are allowed. " +
        "The value is put into a dhall expression on the build agent, so a " +
        "quotation mark or a backslash could run code there.",
    };
  }

  return { value };
};

module.exports = { checkArgument, ALLOWED, MAX_LENGTH };
