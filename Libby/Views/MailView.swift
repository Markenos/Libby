import SwiftUI

struct MailView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: MailItem.ID?

    private var items: [MailItem] {
        model.mail.filter {
            $0.subject.matches(model.search) || $0.sender.matches(model.search) || $0.preview.matches(model.search)
        }
    }

    var body: some View {
        SourceGate(state: model.mailState, permission: AnyView(FullDiskAccessPanel(source: "your mail"))) {
            HStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(items) { m in
                            MailRow(item: m)
                                .modifier(RowBackground(selected: selection == m.id))
                                .onTapGesture { selection = m.id }
                                .simultaneousGesture(TapGesture(count: 2).onEnded { model.open(m) })
                        }
                    }
                    .padding(12)
                }
                .frame(width: 340)
                .overlay { if items.isEmpty { EmptyState(symbol: "envelope", text: "No mail") } }

                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { if selection == nil { selection = items.first?.id } }
    }

    @ViewBuilder private var detail: some View {
        if let m = items.first(where: { $0.id == selection }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(m.subject).font(.system(size: 26, weight: .semibold)).textSelection(.enabled)
                    HStack(spacing: 12) {
                        Avatar(name: m.sender, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.sender).font(.headline)
                            Text(m.senderAddress).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(m.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !m.preview.isEmpty {
                        Text(m.preview)
                            .font(.body).foregroundStyle(.secondary)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    }
                    Button { model.open(m) } label: {
                        Label("Open in Mail", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
                .padding(28)
                .frame(maxWidth: 720, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .padding(24)
            }
        } else {
            EmptyState(symbol: "envelope.open", text: "Select a message")
        }
    }
}

struct MailRow: View {
    let item: MailItem
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(item.isRead ? Color.clear : Color.accentColor)
                .frame(width: 7, height: 7)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.sender).font(.subheadline.weight(item.isRead ? .regular : .semibold)).lineLimit(1)
                    Spacer()
                    if item.isFlagged { Image(systemName: "flag.fill").font(.caption2).foregroundStyle(.orange) }
                    Text(item.date.shortStamp).font(.caption).foregroundStyle(.tertiary)
                }
                Text(item.subject).font(.subheadline).lineLimit(1)
                if !item.preview.isEmpty {
                    Text(item.preview).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
    }
}
