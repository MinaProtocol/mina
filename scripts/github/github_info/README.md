# GitHub info

This script is a catalyst for different simple operations on github. Currently the only one functionality is to checks if a pull request has a specific comment by any of the specified users.

## Installation

Before using the script, make sure to install the required dependencies by running:

```bash
pip install -r requirements.txt
```

## Usage

To check if a pull request has a specific comment by any of the specified users, run the following command:

```bash
python3 scripts/github/github_info is_pr_commented --pr <PR_NUMBER> --comment <COMMENT> --by <USER1> <USER2> ...
```

### Example

```bash
python3 scripts/github/github_info is_pr_commented --pr 1234 --comment "!ci-bypass-changelog" --by dkijania
```

## Notes

- The script uses the GitHub API to fetch comments. If there are too many runs per some unit of time, you might encounter GitHub API throttling. Please be aware of the rate limits and plan accordingly.