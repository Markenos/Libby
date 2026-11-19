import Contacts
import Foundation

/// Maps phone numbers and email addresses to contact names.
final class ContactsResolver: @unchecked Sendable {
    private var byKey: [String: (full: String, short: String)] = [:]

    static func normalize(_ handle: String) -> String {
        if handle.contains("@") { return handle.lowercased() }
        let digits = handle.filter(\.isNumber)
        return String(digits.suffix(9)) // match regardless of country code formatting
    }

    func load() async {
        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        guard granted else { return }
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey, CNContactOrganizationNameKey,
            CNContactPhoneNumbersKey, CNContactEmailAddressesKey,
        ] as [CNKeyDescriptor]
        var map: [String: (String, String)] = [:]
        let request = CNContactFetchRequest(keysToFetch: keys)
        try? store.enumerateContacts(with: request) { c, _ in
            let full = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let name = full.isEmpty ? c.organizationName : full
            guard !name.isEmpty else { return }
            let short = !c.nickname.isEmpty ? c.nickname : (c.givenName.isEmpty ? name : c.givenName)
            for p in c.phoneNumbers { map[Self.normalize(p.value.stringValue)] = (name, short) }
            for e in c.emailAddresses { map[Self.normalize(e.value as String)] = (name, short) }
        }
        byKey = map
    }

    func name(for handle: String, short: Bool = false) -> String {
        guard let hit = byKey[Self.normalize(handle)] else { return handle }
        return short ? hit.short : hit.full
    }
}
