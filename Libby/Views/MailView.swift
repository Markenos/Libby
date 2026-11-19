import SwiftUI

struct MailView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var glass
    @State private var composing = false
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable { case all = "All", unread = "Unread", flagged = "Flagged" }

    private var items: [MailItem] {
        model.mail.filter { m in
            (m.subject.matches(model.search) || m.sender.matches(model.search) || m.preview.matches(model.search))
                && (filter == .all || (filter == .unread && !m.isRead) || (filter == .flagged && m.isFlagged))
        }
    }

    var body: some View {
        @Bindable var model = model
        SourceGate(state: model.mailState, permission: AnyView(FullDiskAccessPanel(source: "your mail"))) {
            HStack(spacing: 18) {
                GlassPanel(tint: AppSection.mail.tint) {
                    VStack(spacing: 0) {
                        HStack {
                            Picker("", selection: $filter) {
                                ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            Button { composing = true } label: { Image(systemName: "square.and.pencil") }
                                .buttonStyle(.glassProminent)
                                .tint(AppSection.mail.tint)
                                .help("New email")
                        }
                        .padding(14)

                        ScrollView {
                            GlassEffectContainer(spacing: 8) {
                                LazyVStack(spacing: 4) {
                                    ForEach(items) { m in
                                        MailRow(item: m)
                                            .modifier(RowBackground(selected: model.selectedMail == m.id,
                                                                    tint: AppSection.mail.tint, namespace: glass))
                                            .onTapGesture { withAnimation(.smooth(duration: 0.3)) { model.selectedMail = m.id } }
                                            .simultaneousGesture(TapGesture(count: 2).onEnded { model.open(m) })
                                            .contextMenu { actions(for: m) }
                                    }
                                }
                                .padding(.horizontal, 10).padding(.bottom, 10)
                            }
                        }
                        .overlay { if items.isEmpty { EmptyState(symbol: "envelope", text: "No mail") } }
                    }
                }
                .frame(width: 360)

                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(18)
        }
        .onAppear { if model.selectedMail == nil { model.selectedMail = items.first?.id } }
        .sheet(isPresented: $composing) { ComposeMailSheet() }
    }

    @ViewBuilder private func actions(for m: MailItem) -> some View {
        Button(m.isRead ? "Mark as Unread" : "Mark as Read", systemImage: m.isRead ? "envelope.badge" : "envelope.open") {
            Task { await model.mail(m.isRead ? .markUnread : .markRead, m) }
        }
        Button(m.isFlagged ? "Unflag" : "Flag", systemImage: "flag") {
            Task { await model.mail(m.isFlagged ? .unflag : .flag, m) }
        }
        Button("Archive", systemImage: "archivebox") { Task { await model.mail(.archive, m) } }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { Task { await model.mail(.delete, m) } }
    }

    @ViewBuilder private var detail: some View {
        if let m = model.mail.first(where: { $0.id == model.selectedMail }) {
            MailDetail(item: m).id(m.id)
        } else {
            EmptyState(symbol: "envelope.open", text: "Select a message")
        }
    }
}

struct MailDetail: View {
    @Environment(AppModel.self) private var model
    let item: MailItem
    @State private var reply = ""
    @State private var replyAll = false
    @State private var sending = false

    var body: some View {
        VStack(spacing: 14) {
            toolbar
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        Text(item.subject).font(.system(size: 26, weight: .bold, design: .rounded)).textSelection(.enabled)
                        Spacer()
                        Text(item.mailbox)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .glassEffect(.regular.tint(AppSection.mail.tint.opacity(0.2)), in: .capsule)
                    }
                    HStack(spacing: 12) {
                        Avatar(name: item.sender, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.sender).font(.headline)
                            Text(item.senderAddress).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(item.preview.isEmpty ? "No preview available — open in Mail to read the full message." : item.preview)
                        .font(.body).foregroundStyle(item.preview.isEmpty ? .secondary : .primary)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                    Button { model.open(item) } label: {
                        Label("Read full message in Mail", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.glass)
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 30))

            replyBox
        }
        .task {
            if !item.isRead { await model.mail(.markRead, item) }
        }
    }

    private var toolbar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                glassButton(item.isRead ? "envelope.badge" : "envelope.open", item.isRead ? "Mark unread" : "Mark read") {
                    await model.mail(item.isRead ? .markUnread : .markRead, item)
                }
                glassButton(item.isFlagged ? "flag.fill" : "flag", item.isFlagged ? "Unflag" : "Flag",
                            tint: item.isFlagged ? .orange : nil) {
                    await model.mail(item.isFlagged ? .unflag : .flag, item)
                }
                glassButton("archivebox", "Archive") { await model.mail(.archive, item) }
                glassButton("trash", "Delete", tint: .red) { await model.mail(.delete, item) }
                Spacer()
                glassButton("arrow.up.forward.app", "Open in Mail") { model.open(item) }
            }
        }
    }

    private func glassButton(_ symbol: String, _ help: String, tint: Color? = nil,
                             _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: symbol).frame(width: 18, height: 18)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .tint(tint)
        .help(help)
    }

    private var replyBox: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Menu {
                Button("Reply") { replyAll = false }
                Button("Reply All") { replyAll = true }
            } label: {
                Image(systemName: replyAll ? "arrowshape.turn.up.left.2.fill" : "arrowshape.turn.up.left.fill")
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .fixedSize()
            .help(replyAll ? "Reply all" : "Reply")

            TextField(replyAll ? "Reply all to \(item.sender)…" : "Reply to \(item.sender)…", text: $reply, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))

            Button {
                sending = true
                Task {
                    if await model.reply(to: item, body: reply, all: replyAll) { reply = "" }
                    sending = false
                }
            } label: {
                if sending { ProgressView().controlSize(.small) } else { Image(systemName: "paperplane.fill") }
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .tint(AppSection.mail.tint)
            .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Send reply (⌘↩)")
        }
    }
}

struct MailRow: View {
    let item: MailItem
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topLeading) {
                Avatar(name: item.sender, size: 36)
                if !item.isRead {
                    Circle().fill(AppSection.mail.tint).frame(width: 11, height: 11)
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                        .offset(x: -2, y: -2)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.sender).font(.subheadline.weight(item.isRead ? .regular : .semibold)).lineLimit(1)
                    Spacer()
                    if item.isFlagged { Image(systemName: "flag.fill").font(.caption2).foregroundStyle(.orange) }
                    Text(item.date.shortStamp).font(.caption).foregroundStyle(.tertiary)
                }
                Text(item.subject).font(.subheadline.weight(item.isRead ? .regular : .medium)).lineLimit(1)
                if !item.preview.isEmpty {
                    Text(item.preview).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
    }
}

struct ComposeMailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var to = ""
    @State private var subject = ""
    @State private var bodyText = ""
    @State private var sending = false

    private var recipients: [String] {
        to.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == " " }).map(String.init).filter { $0.contains("@") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconBadge(symbol: "square.and.pencil", tint: AppSection.mail.tint)
                Text("New Email").font(.title3.weight(.semibold))
            }
            field("To", text: $to, prompt: "name@example.com")
            field("Subject", text: $subject, prompt: "")
            TextEditor(text: $bodyText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 220)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
            HStack {
                Text("Sends from your default account in Mail.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.glass)
                Button {
                    sending = true
                    Task {
                        if await model.compose(to: recipients, subject: subject, body: bodyText) { dismiss() }
                        sending = false
                    }
                } label: {
                    if sending { ProgressView().controlSize(.small) } else { Label("Send", systemImage: "paperplane.fill") }
                }
                .buttonStyle(.glassProminent)
                .tint(AppSection.mail.tint)
                .disabled(recipients.isEmpty || sending)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
            TextField(label, text: text, prompt: Text(prompt)).textFieldStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}
