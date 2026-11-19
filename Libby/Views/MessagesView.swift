import SwiftUI

struct MessagesView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Conversation.ID?
    @State private var thread: [ChatMessage] = []

    private var items: [Conversation] {
        model.conversations.filter { $0.title.matches(model.search) || $0.lastText.matches(model.search) }
    }

    var body: some View {
        SourceGate(state: model.messagesState, permission: AnyView(FullDiskAccessPanel(source: "your messages"))) {
            HStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(items) { c in
                            ConversationRow(chat: c)
                                .modifier(RowBackground(selected: selection == c.id))
                                .onTapGesture { selection = c.id }
                        }
                    }
                    .padding(12)
                }
                .frame(width: 320)
                .overlay { if items.isEmpty { EmptyState(symbol: "message", text: "No conversations") } }

                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { if selection == nil { selection = items.first?.id } }
        .task(id: selection) {
            guard let chat = model.conversations.first(where: { $0.id == selection }) else { thread = []; return }
            thread = await model.messages(in: chat)
        }
    }

    @ViewBuilder private var detail: some View {
        if let chat = model.conversations.first(where: { $0.id == selection }) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(thread.enumerated()), id: \.element.id) { i, msg in
                            if i == 0 || msg.date.timeIntervalSince(thread[i - 1].date) > 3600 {
                                Text(msg.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2).foregroundStyle(.tertiary)
                                    .padding(.top, 12)
                            }
                            Bubble(message: msg, showSender: chat.isGroup && !msg.isFromMe
                                   && (i == 0 || thread[i - 1].sender != msg.sender))
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 72)
                    .padding(.bottom, 24)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: thread) { _, t in if let last = t.last { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
            .overlay(alignment: .top) {
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Avatar(name: chat.title, size: 26)
                            Text(chat.title).font(.headline).lineLimit(1)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .glassEffect()

                        Button { model.open(chat) } label: {
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .buttonStyle(.glass)
                        .help("Open in Messages")
                    }
                }
                .padding(.top, 14)
            }
        } else {
            EmptyState(symbol: "bubble.left.and.bubble.right", text: "Select a conversation")
        }
    }
}

struct ConversationRow: View {
    let chat: Conversation
    var body: some View {
        HStack(spacing: 12) {
            Avatar(name: chat.title, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(chat.title).font(.subheadline.weight(chat.unread > 0 ? .semibold : .regular)).lineLimit(1)
                    Spacer()
                    Text(chat.lastDate.shortStamp).font(.caption).foregroundStyle(.tertiary)
                }
                HStack {
                    Text(chat.lastText).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer(minLength: 0)
                    if chat.unread > 0 { Circle().fill(Color.accentColor).frame(width: 8, height: 8) }
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
                .glassEffect(message.isFromMe ? .regular.tint(.accentColor) : .regular,
                             in: .rect(cornerRadius: 18))
                if !message.isFromMe { Spacer(minLength: 80) }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isFromMe ? .trailing : .leading)
    }
}
