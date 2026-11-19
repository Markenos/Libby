# Libby

Your Mail, Messages, Calendar and Reminders in one quiet, Liquid Glass window on your Mac.

- **Today**: today's agenda, reminders that are due, unread mail and recent conversations
- **Mail**: recent received mail from every account in Apple Mail; double-click to open in Mail
- **Messages**: your iMessage/SMS conversations (read-only)
- **Calendar**: the next two weeks
- **Reminders**: grouped by list, tick them off right here

Everything is read straight from your Mac. Nothing leaves it, and there are no accounts to set up.

## Install

```bash
brew tap markenos/libby https://github.com/Markenos/Libby
brew install --cask libby
```

Update to the latest build:

```bash
brew update && brew upgrade --cask libby
```

Requires macOS 26 (Tahoe) or later.

## Permissions

- **Calendar, Reminders, Contacts**: macOS asks the first time you open Libby.
- **Full Disk Access** (for Mail and Messages): System Settings → Privacy & Security → Full Disk Access → turn on Libby, then reopen it. Because builds are ad-hoc signed, you may need to turn this on again after an update.

## Develop

Needs Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make run        # build and launch
make selftest   # print what the Mail/Messages readers find
```

Every push to `main` builds a release on GitHub Actions and updates `Casks/libby.rb`, so `brew upgrade` picks it up a few minutes later.
