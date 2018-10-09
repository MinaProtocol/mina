# Coda code review guidelines

A good pull request:

- Does about one thing (new feature, bug fix, etc)
- Adds tests and documentation for any new functionality
- When fixing a bug, adds or fixes test that would have caught said bug

# OCaml things

- Do the signatures make sense? Are they minimal and reusable?
- Does anything need to be functored over?
- Are there any error cases that aren't handled correctly?
- Are there comments describing the major "why" for the code where it is
  confusing?
- There shouldn't be commented out code
- No stray debug code lying around.
- Any logging is appropriate. All `Logger.trace` logs should be inessential,
  because they won't be shown to anyone by default.
- Should this code live in its library? Should it live in a different library?
