#!/usr/bin/env python3

"""Keep only the wanted debian packages in a pipeline that is about to be uploaded.

One step of a job builds every debian package of that job:

    build-from-cache.sh <variant> <token> <token> ...

This reads a pipeline on stdin, cuts that list down to the tokens that match the
patterns given, and writes the pipeline out again.

    narrow_debian_tokens.py 'prefork_*' logproc < pipeline.yml > narrowed.yml

The token list is written more than once in the same step: once in the `echo
"-- Running: ..."` line that the log shows, and once in the command that really
runs. Both are changed, so the log does not say something other than what ran.

Nothing else in the pipeline is touched. When no token matches, the run stops:
building nothing is never what was meant, and a silent empty list would make
build.sh fall back to building EVERY default package.
"""

import fnmatch
import re
import sys

# build-from-cache.sh <variant> <token> <token> ...
# A token is lower case letters, digits and underscores. The list ends at the
# first word that is not one, which is how the two forms of the line (the echo
# and the real command) both end.
CALL = re.compile(
    r"(build-from-cache\.sh\s+)([A-Za-z0-9_]+)((?:\s+[a-z0-9_]+)+)"
)


def narrow_line(line, patterns, report):
    def replace(match):
        head, variant, tokens = match.group(1), match.group(2), match.group(3)
        wanted = [
            token
            for token in tokens.split()
            if any(fnmatch.fnmatchcase(token, p) for p in patterns)
        ]
        report["seen"].update(tokens.split())
        report["kept"].update(wanted)
        if not wanted:
            # Leave the line alone; the caller stops the run.
            return match.group(0)
        return head + variant + " " + " ".join(wanted)

    return CALL.sub(replace, line)


def main():
    patterns = sys.argv[1:]
    if not patterns:
        sys.stderr.write("usage: narrow_debian_tokens.py PATTERN [PATTERN ...]\n")
        return 2

    report = {"seen": set(), "kept": set()}
    text = sys.stdin.read()
    out = "\n".join(narrow_line(line, patterns, report) for line in text.split("\n"))

    if not report["seen"]:
        sys.stderr.write(
            "narrow_debian_tokens.py: no build-from-cache.sh call was found, "
            "so nothing was narrowed.\n"
        )
        return 1

    if not report["kept"]:
        sys.stderr.write(
            "narrow_debian_tokens.py: no debian package matches %s.\n"
            "  These are built by this job:\n%s\n"
            % (
                " ".join(patterns),
                "\n".join("    " + t for t in sorted(report["seen"])),
            )
        )
        return 1

    dropped = sorted(report["seen"] - report["kept"])
    sys.stderr.write(
        "narrow_debian_tokens.py: keeping %d of %d packages (%s)\n"
        % (
            len(report["kept"]),
            len(report["seen"]),
            " ".join(sorted(report["kept"])),
        )
    )
    if dropped:
        sys.stderr.write("  not built: %s\n" % " ".join(dropped))

    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
