import Foundation

/// `Libby --selftest` prints a summary of what the Mail and Messages readers find, then exits.
/// Handy for checking the database queries after a macOS update.
enum SelfTest {
    static func run() -> Never {
        let names = ContactsResolver()
        print("Mail DB:", MailSource.databasePath ?? "not found", "access:", MailSource.hasAccess)
        do {
            let mail = try MailSource.load(limit: 50)
            print("Mail: \(mail.count) items, \(mail.filter { !$0.isRead }.count) unread, \(mail.filter { $0.mailURL != nil }.count) openable")
            if let m = mail.first { print("  latest:", m.date, "| subject length", m.subject.count, "| preview length", m.preview.count) }
        } catch { print("Mail error:", error) }

        print("Messages access:", MessagesSource.hasAccess)
        do {
            let convos = try MessagesSource.conversations(limit: 30, names: names)
            let withText = convos.filter { !$0.lastText.isEmpty }.count
            print("Messages: \(convos.count) conversations, \(withText) with preview text, \(convos.filter(\.isGroup).count) groups")
            if let c = convos.first {
                let msgs = try MessagesSource.messages(chatID: c.id, limit: 50, names: names)
                print("  latest thread: \(msgs.count) messages, \(msgs.filter { !$0.text.isEmpty }.count) with text, last at \(c.lastDate)")
            }
        } catch { print("Messages error:", error) }
        exit(0)
    }
}
