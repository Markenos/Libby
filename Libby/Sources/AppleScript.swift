import Foundation

/// Runs AppleScript through `osascript`, passing user text as arguments (never spliced into the
/// script source), so message bodies and addresses can't break or inject into the script.
enum AppleScript {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @discardableResult
    static func run(_ source: String, _ args: [String] = []) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-"] + args
            let input = Pipe(), output = Pipe(), errors = Pipe()
            p.standardInput = input
            p.standardOutput = output
            p.standardError = errors
            try p.run()
            input.fileHandleForWriting.write(Data(source.utf8))
            try input.fileHandleForWriting.close()
            let out = output.fileHandleForReading.readDataToEndOfFile()
            let err = errors.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else {
                var msg = String(decoding: err, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                if msg.contains("-1743") || msg.localizedCaseInsensitiveContains("not authori") {
                    msg = "Libby isn't allowed to control this app. Turn it on in System Settings › Privacy & Security › Automation."
                } else if let r = msg.range(of: #"execution error: "#) {
                    msg = String(msg[r.upperBound...])
                }
                throw Failure(message: msg.isEmpty ? "AppleScript failed" : msg)
            }
            return String(decoding: out, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }
}

// MARK: - Messages

enum MessagesActions {
    /// Sends to an existing conversation (works for groups too).
    static func send(_ text: String, toChatGUID guid: String) async throws {
        try await AppleScript.run("""
        on run argv
            tell application "Messages" to send (item 1 of argv) to chat id (item 2 of argv)
        end run
        """, [text, guid])
    }

    /// Starts (or continues) a one-to-one conversation with a phone number or email.
    static func send(_ text: String, toHandle handle: String) async throws {
        try await AppleScript.run("""
        on run argv
            set msg to item 1 of argv
            set who to item 2 of argv
            tell application "Messages"
                try
                    set svc to 1st account whose service type = iMessage
                    send msg to participant who of svc
                on error
                    set svc to 1st account whose service type = SMS
                    send msg to participant who of svc
                end try
            end tell
        end run
        """, [text, handle])
    }
}

// MARK: - Mail

enum MailActions {
    enum Action: String { case markRead, markUnread, flag, unflag, delete, archive }

    /// Finds the message by Message-ID inside the mailbox Libby read it from, then acts on it.
    static func perform(_ action: Action, on item: MailItem) async throws {
        guard let loc = item.location else { throw AppleScript.Failure(message: "Can't locate this message in Mail.") }
        try await AppleScript.run("""
        on run argv
            set acctID to item 1 of argv
            set boxPath to item 2 of argv
            set mid to item 3 of argv
            set act to item 4 of argv
            tell application "Mail"
                set acct to first account whose id is acctID
                set mb to mailbox boxPath of acct
                set m to first message of mb whose message id is mid
                if act is "markRead" then
                    set read status of m to true
                else if act is "markUnread" then
                    set read status of m to false
                else if act is "flag" then
                    set flagged status of m to true
                else if act is "unflag" then
                    set flagged status of m to false
                else if act is "delete" then
                    delete m
                else if act is "archive" then
                    set target to missing value
                    repeat with n in {"Archive", "[Gmail]/All Mail", "Archives"}
                        try
                            set target to mailbox (n as text) of acct
                            exit repeat
                        end try
                    end repeat
                    if target is missing value then error "This account has no Archive mailbox."
                    if (name of mb) is not (name of target) then move m to target
                end if
            end tell
        end run
        """, [loc.account, loc.mailbox, loc.messageID, action.rawValue])
    }

    static func reply(to item: MailItem, body: String, replyAll: Bool) async throws {
        guard let loc = item.location else { throw AppleScript.Failure(message: "Can't locate this message in Mail.") }
        try await AppleScript.run("""
        on run argv
            tell application "Mail"
                set acct to first account whose id is (item 1 of argv)
                set m to first message of (mailbox (item 2 of argv) of acct) whose message id is (item 3 of argv)
                if (item 5 of argv) is "all" then
                    set r to reply m with reply to all without opening window
                else
                    set r to reply m without opening window
                end if
                set content of r to (item 4 of argv) & return & return & (content of r)
                send r
            end tell
        end run
        """, [loc.account, loc.mailbox, loc.messageID, body, replyAll ? "all" : "one"])
    }

    static func compose(to: [String], subject: String, body: String) async throws {
        try await AppleScript.run("""
        on run argv
            set subj to item 1 of argv
            set bodyText to item 2 of argv
            tell application "Mail"
                set msg to make new outgoing message with properties {subject:subj, content:bodyText, visible:false}
                repeat with i from 3 to count of argv
                    tell msg to make new to recipient at end of to recipients with properties {address:(item i of argv)}
                end repeat
                send msg
            end tell
        end run
        """, [subject, body] + to)
    }
}
