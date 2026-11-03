# Security policy

## Supported versions

Only the latest release and the `main` branch receive fixes.

## Reporting a problem

Please do not open a public issue for a security problem. Report it privately through GitHub instead:

1. Go to the repository's **Security** tab.
2. Choose **Report a vulnerability**.
3. Describe the problem, how to reproduce it, and what it could affect.

Tallow is maintained by one person in their own time. We aim to acknowledge a report within 7 days and will keep you updated as we work on it. We will credit you in the release notes unless you would rather not be named.

## Scope

In scope: the game's code and the CI workflows, and, once they exist, the web build on GitHub Pages and the release artefacts.

Out of scope: third-party engines, libraries and assets (report those to their owners), and problems that need an already compromised machine.

## Secrets

The repository holds no secrets. CI reads what it needs from GitHub's encrypted secrets, and GitHub secret scanning with push protection is turned on.
