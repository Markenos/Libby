# Libby

Your Mail, Messages, Calendar and Reminders in one quiet, Liquid Glass window on your Mac.

- **Today**: today's agenda, reminders that are due, unread mail and recent conversations
- **Mail**: recent mail from every account in Apple Mail. Reply, write new emails, mark read/unread, flag, archive and delete
- **Messages**: your iMessage/SMS conversations. Reply in any chat or start a new one
- **Calendar**: the next two weeks
- **Reminders**: grouped by list, tick them off right here

Everything is read straight from your Mac. Sending and managing go through Mail and Messages themselves. Nothing leaves it, and there are no accounts to set up.

## Install

```bash
brew tap markenos/libby https://github.com/Markenos/Libby
brew trust markenos/libby
brew install --cask libby
```

Update to the latest build:

```bash
brew update && brew upgrade --cask libby
```

Requires macOS 26 (Tahoe) or later.

## Permissions

- **Calendar, Reminders, Contacts**: macOS asks the first time you open Libby.
- **Automation** (to send and manage): macOS asks the first time Libby talks to Mail or Messages.
- **Full Disk Access** (for Mail and Messages): System Settings → Privacy & Security → Full Disk Access → turn on Libby, then reopen it. Because builds are ad-hoc signed, you may need to turn this on again after an update.

## Develop

Needs Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make run        # build and launch
make selftest   # print what the Mail/Messages readers find
```

Every push to `main` builds a release on GitHub Actions and updates `Casks/libby.rb`, so `brew upgrade` picks it up a few minutes later.
