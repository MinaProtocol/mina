import argparse
import requests

def is_pr_commented(pr_number, comment, users):
    """
    Check if a pull request has a specific comment by any of the specified users.

    Args:
        pr_number (int): The pull request number.
        comment (str): The comment to check for.
        users (list): The list of users to check for.

    Returns:
        bool: True if the comment is found by any of the specified users, False otherwise.

    Raises:
        Exception: If the GitHub API request fails.
    """
    url = f"https://api.github.com/repos/minaprotocol/mina/issues/{pr_number}/comments"
    response = requests.get(url)
    if response.status_code != 200:
        raise Exception(f"Failed to fetch comments for PR #{pr_number}: {response.status_code} {response.text}")

    comments = response.json()
    for c in comments:
        if c['body'] == comment and c['user']['login'] in users:
            return True
    return False

def main():
    """
    Main function to parse arguments and execute the appropriate command.
    """
    parser = argparse.ArgumentParser(description="GitHub PR Comment Checker")
    subparsers = parser.add_subparsers(dest="command")

    is_pr_commented_parser = subparsers.add_parser('is_pr_commented', help='Check if a PR is commented')
    is_pr_commented_parser.add_argument('--pr', type=int, required=True, help='PR number')
    is_pr_commented_parser.add_argument('--comment', type=str, required=True, help='Comment to check for')
    is_pr_commented_parser.add_argument('--by', type=str, nargs='+', required=True, help='Users to check for')

    args = parser.parse_args()

    if args.command == 'is_pr_commented':
        if is_pr_commented(args.pr, args.comment, args.by):
            print(f"PR #{args.pr} has the comment '{args.comment}' by one of the specified users.")
            exit(0)
        else:
            print(f"PR #{args.pr} does not have the comment '{args.comment}' by any of the specified users.")
            exit(1)

if __name__ == "__main__":
    main()