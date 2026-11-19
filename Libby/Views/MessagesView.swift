import SwiftUI

struct MessagesView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var glass
    @State private var thread: [ChatMessage] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var newMessage = false

    private var items: [Conversation] {
        model.conversations.filter { $0.title.matches(model.search) || $0.lastText.matches(model.search) }
    }

    private var selected: Conversation? { model.conversations.first { $0.id == model.selectedChat } }

    var body: some View {
        SourceGate(state: model.messagesState, permission: AnyView(FullDiskAccessPanel(source: "your messages"))) {
            HStack(spacing: 18) {
                GlassPanel(tint: AppSection.messages.tint) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Conversations").font(.headline)
                            Spacer()
                            Button { newMessage = true } label: { Image(systemName: "square.and.pencil") }
                                .buttonStyle(.glassProminent)
                                .tint(AppSection.messages.tint)
                                .help("New message")
                        }
                        .padding(14)
                        ScrollView {
                            GlassEffectContainer(spacing: 8) {
                                LazyVStack(spacing: 4) {
                                    ForEach(items) { c in
                                        ConversationRow(chat: c)
                                            .modifier(RowBackground(selected: model.selectedChat == c.id,
                                                                    tint: AppSection.messages.tint, namespace: glass))
                                            .onTapGesture { withAnimation(.smooth(duration: 0.3)) { model.selectedChat = c.id } }
                                            .contextMenu {
                                                Button("Open in Messages", systemImage: "arrow.up.forward.app") { model.open(c) }
                                            }
                                    }
                                }
                                .padding(.horizontal, 10).padding(.bottom, 10)
                            }
                        }
                        .overlay { if items.isEmpty { EmptyState(symbol: "message", text: "No conversations") } }
                    }
                }
                .frame(width: 330)

                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(18)
        }
        .onAppear { if model.selectedChat == nil { model.selectedChat = items.first?.id } }
        .task(id: "\(model.selectedChat ?? -1)-\(model.threadVersion)") {
            guard let chat = selected else { thread = []; return }
            thread = await model.messages(in: chat)
        }
        .sheet(isPresented: $newMessage) { NewMessageSheet() }
    }

    @ViewBuilder private var detail: some View {
        if let chat = selected {
            VStack(spacing: 14) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(thread.enumerated()), id: \.element.id) { i, msg in
                                if i == 0 || msg.date.timeIntervalSince(thread[i - 1].date) > 3600 {
                                    Text(msg.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .glassEffect()
                                        .padding(.top, 12)
                                }
                                Bubble(message: msg, showSender: chat.isGroup && !msg.isFromMe
                                       && (i == 0 || thread[i - 1].sender != msg.sender))
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 76)
                        .padding(.bottom, 16)
                    }
                    .defaultScrollAnchor(.bottom)
                    .onChange(of: thread) { _, t in
                        if let last = t.last { withAnimation(.smooth) { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                .overlay(alignment: .top) { header(chat) }
                .glassEffect(.regular.tint(AppSection.messages.tint.opacity(0.04)), in: .rect(cornerRadius: 30))

                composer(chat)
            }
        } else {
            EmptyState(symbol: "bubble.left.and.bubble.right", text: "Select a conversation")
        }
    }

    private func header(_ chat: Conversation) -> some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Avatar(name: chat.title, size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(chat.title).font(.headline).lineLimit(1)
                        Text(chat.isGroup ? "\(chat.handles.count) people" : (chat.handles.first ?? ""))
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .padding(.leading, 8).padding(.trailing, 16).padding(.vertical, 7)
                .glassEffect(.regular.interactive())

                Button { model.open(chat) } label: { Image(systemName: "arrow.up.forward.app") }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .help("Open in Messages")
            }
        }
        .padding(.top, 14)
    }

    private func composer(_ chat: Conversation) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(chat.handles.first?.contains("@") == false && !chat.guid.hasPrefix("iMessage") ? "Text Message" : "iMessage",
                      text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(.horizontal, 18).padding(.vertical, 11)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                .onSubmit { send(chat) }

            Button { send(chat) } label: {
                if sending { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.up") .fontWeight(.bold) }
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .tint(AppSection.messages.tint)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
            .help("Send (↩)")
        }
    }

    private func send(_ chat: Conversation) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        sending = true
        draft = ""
        Task {
            if !(await model.send(text, to: chat)) { draft = text }
            sending = false
        }
    }
}

struct ConversationRow: View {
    let chat: Conversation
    var body: some View {
        HStack(spacing: 12) {
            Avatar(name: chat.title, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(chat.title).font(.subheadline.weight(chat.unread > 0 ? .semibold : .regular)).lineLimit(1)
                    Spacer()
                    Text(chat.lastDate.shortStamp).font(.caption).foregroundStyle(.tertiary)
                }
                HStack {
                    Text(chat.lastText).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer(minLength: 0)
                    if chat.unread > 0 {
                        Text("\(chat.unread)")
                            .font(.caption2.weight(.bold)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(AppSection.messages.tint))
                    }
                }
            }
        }
    }
}

struct Bubble: View {
    let message: ChatMessage
    let showSender: Bool

    var body: some View {
        VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 2) {
            if showSender, let s = message.sender {
                Text(s).font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 12)
            }
            HStack {
                if message.isFromMe { Spacer(minLength: 80) }
                VStack(alignment: .leading, spacing: 4) {
                    if message.hasAttachment && message.text.isEmpty {
                        Label("Attachment", systemImage: "paperclip").font(.callout)
                    } else {
                        Text(message.text).textSelection(.enabled)
                        if message.hasAttachment {
                            Label("Attachment", systemImage: "paperclip").font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .foregroundStyle(message.isFromMe ? .white : .primary)
                .glassEffect(message.isFromMe ? .regular.tint(.blue.opacity(0.9)) : .regular,
                             in: .rect(cornerRadius: 20))
                if !message.isFromMe { Spacer(minLength: 80) }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isFromMe ? .trailing : .leading)
    }
}

struct NewMessageSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var to = ""
    @State private var text = ""
    @State private var sending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconBadge(symbol: "message.fill", tint: AppSection.messages.tint)
                Text("New Message").font(.title3.weight(.semibold))
            }
            HStack {
                Text("To").foregroundStyle(.secondary).frame(width: 30, alignment: .leading)
                TextField("To", text: $to, prompt: Text("Phone number or email")).textFieldStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))

            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(4...10)
                .padding(14)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))

            HStack {
                Text("Sends as iMessage, or SMS if iMessage isn't available.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.glass)
                Button {
                    sending = true
                    Task {
                        if await model.sendNew(text, to: to.trimmingCharacters(in: .whitespaces)) {
                            model.section = .messages
                            dismiss()
                        }
                        sending = false
                    }
                } label: {
                    if sending { ProgressView().controlSize(.small) } else { Label("Send", systemImage: "arrow.up") }
                }
                .buttonStyle(.glassProminent)
                .tint(AppSection.messages.tint)
                .disabled(to.trimmingCharacters(in: .whitespaces).isEmpty
                          || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
