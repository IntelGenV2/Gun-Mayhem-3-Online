# GitHub setup

Create the repository without a generated .gitignore or license. This project's
.gitignore excludes generated bundles, SDKs, original SWFs/audio/fonts, local
signing certificates and credentials. Keep source, build scripts, tests, and
asset attribution documents in Git.

MIT is an option for the newly authored mod, desktop shell and networking code
if the project's author chooses to grant that permission. No license has been
applied by this setup document. A license for new code does not license the
original Gun Mayhem game, art, music, fonts, or third-party SDKs/runtimes.
Those components retain their owners' rights and applicable terms, including
any requirements for distribution in release downloads. See assets/CREDITS.md.

The planned update checker needs the repository URL and published GitHub Releases
with version tags (for example v0.5.0) and the portable Windows ZIP attached.
Public release checks do not need a GitHub token. Never put an account token or
private signing key in the shipped game. Publishing or uploading is a separate
step; the local build does not create a GitHub release automatically.
