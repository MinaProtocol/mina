#!/usr/bin/env python3

"""
Main entrypoint for the hardfork testing suite.

This is the Python equivalent of build-and-test.sh and provides
the same interface while using all library functions internally.
"""

import sys
from build_and_test import build_and_test


def main():
    """
    Main entrypoint that mimics the original build-and-test.sh behavior.
    
    When given an argument, it treats itself as being run in Buildkite CI 
    and the argument as the "fork" branch that needs to be built.
    
    When it isn't given any arguments, it assumes it is being executed 
    locally and builds code in $PWD as the fork branch.
    """
    branch = sys.argv[1] if len(sys.argv) > 1 else None
    
    # Run the build and test process
    success = build_and_test(branch)
    
    if not success:
        sys.exit(1)
    
    print("Hardfork build and test completed successfully!")


if __name__ == "__main__":
    main()