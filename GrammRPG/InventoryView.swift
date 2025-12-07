import SwiftUI
import SwiftData

struct InventoryView: View {
    let items: [Item]
    var onClose: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items, id: \.persistentModelID) { item in
                            VStack(spacing: 8) {
                                Image(systemName: "shippingbox.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 56, height: 56)
                                    .foregroundStyle(.tint)
                                    .padding(12)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                if let name = item.name, !name.isEmpty {
                                    Text(name)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .multilineTextAlignment(.center)
                                } else {
                                    Text(item.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                                        .font(.headline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(12)
                }
                #if os(iOS)
                HStack { Spacer() }
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .overlay(Rectangle().fill(.white.opacity(0.2)).frame(height: 0.5), alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -2)
                    .padding([.horizontal, .bottom])
                #endif
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let onClose {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let onOpenSettings {
                        Button(action: onOpenSettings) {
                            Image(systemName: "gearshape.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
