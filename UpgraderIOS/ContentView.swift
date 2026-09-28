
import SwiftUI

struct Skin: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let weapon: String
    let rarity: String
    let rarityColor: String?
    let price: Double
    let imageUrl: String?
    let marketHashName: String?
}

@MainActor
final class GameStore: ObservableObject {
    @Published var skins: [Skin] = []
    @Published var inventory: [Skin] = []
    @Published var balance: Double = 100.0
    @Published var history: [String] = []
    @Published var selectedInput: Skin?
    @Published var selectedTarget: Skin?
    @Published var message = "Выбери предмет и более дорогую цель"

    init() {
        load()
    }

    func load() {
        guard let url = Bundle.main.url(forResource: "skins_database", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Skin].self, from: data) else { return }
        skins = decoded
        inventory = Array(decoded.prefix(8))
    }

    func chance() -> Double {
        guard let a = selectedInput, let b = selectedTarget, b.price > 0 else { return 0 }
        return min(75, max(1, (a.price / b.price) * 100))
    }

    func spin() {
        guard let a = selectedInput, let b = selectedTarget else { return }
        let c = chance()
        let win = Double.random(in: 0...100) <= c
        if win {
            inventory.removeAll { $0.id == a.id }
            inventory.append(b)
            message = "ПОБЕДА: \(b.name)"
            history.insert("Выигрыш • \(b.name)", at: 0)
        } else {
            inventory.removeAll { $0.id == a.id }
            message = "Не повезло. Ставка потеряна."
            history.insert("Проигрыш • \(a.name)", at: 0)
        }
        selectedInput = nil
        selectedTarget = nil
        save()
    }

    func buy(_ skin: Skin) {
        guard balance >= skin.price else { return }
        balance -= skin.price
        inventory.append(skin)
        history.insert("Покупка • \(skin.name)", at: 0)
        save()
    }

    func sell(_ skin: Skin) {
        balance += skin.price
        inventory.removeAll { $0.id == skin.id }
        history.insert("Продажа • \(skin.name)", at: 0)
        save()
    }

    func save() {
        UserDefaults.standard.set(balance, forKey: "balance")
        UserDefaults.standard.set(inventory.map(\.id), forKey: "inventory")
    }
}

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        TabView {
            UpgradeView().tabItem { Label("Апгрейд", systemImage: "arrow.up.circle.fill") }
            InventoryView().tabItem { Label("Инвентарь", systemImage: "shippingbox.fill") }
            ShopView().tabItem { Label("Магазин", systemImage: "cart.fill") }
            HistoryView().tabItem { Label("История", systemImage: "clock.fill") }
        }
        .preferredColorScheme(.dark)
    }
}

struct SkinCard: View {
    let skin: Skin
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: skin.imageUrl ?? "")) { image in
                image.resizable().scaledToFit()
            } placeholder: { ProgressView() }
            .frame(width: 64, height: 48)
            VStack(alignment: .leading) {
                Text(skin.name).font(.subheadline).lineLimit(2)
                Text("$\(skin.price, specifier: "%.2f")").foregroundStyle(.green).font(.caption.bold())
            }
        }
    }
}

struct UpgradeView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Text("Баланс").foregroundStyle(.secondary)
                        Spacer()
                        Text("$\(store.balance, specifier: "%.2f")").bold().foregroundStyle(.green)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    Text(store.message).font(.headline).multilineTextAlignment(.center)

                    if let input = store.selectedInput {
                        SkinCard(skin: input)
                        Text("↓").font(.largeTitle)
                    }

                    if let target = store.selectedTarget {
                        SkinCard(skin: target)
                        Text("Шанс: \(store.chance(), specifier: "%.1f")%").foregroundStyle(.orange)
                    }

                    Button("КРУТИТЬ") { store.spin() }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.selectedInput == nil || store.selectedTarget == nil)

                    Divider()
                    Text("Выбери ставку").font(.headline)
                    ForEach(store.inventory.prefix(20)) { skin in
                        Button {
                            store.selectedInput = skin
                        } label: {
                            SkinCard(skin: skin)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Выбери цель").font(.headline)
                    ForEach(store.skins.filter {
                        guard let input = store.selectedInput else { return $0.price > 0 }
                        return $0.price > input.price
                    }.prefix(30)) { skin in
                        Button { store.selectedTarget = skin } label: {
                            SkinCard(skin: skin)
                        }
                        .buttonStyle(.plain)
                    }
                }.padding()
            }
            .navigationTitle("Upgrader")
        }
    }
}

struct InventoryView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        NavigationStack {
            List(store.inventory) { skin in
                HStack {
                    SkinCard(skin: skin)
                    Spacer()
                    Button("Продать") { store.sell(skin) }
                        .buttonStyle(.bordered)
                }
            }.navigationTitle("Инвентарь")
        }
    }
}

struct ShopView: View {
    @EnvironmentObject var store: GameStore
    @State private var search = ""
    var filtered: [Skin] {
        let q = search.lowercased()
        return store.skins.filter { q.isEmpty || $0.name.lowercased().contains(q) }
    }
    var body: some View {
        NavigationStack {
            List(filtered.prefix(150)) { skin in
                HStack {
                    SkinCard(skin: skin)
                    Spacer()
                    Button("Купить") { store.buy(skin) }
                }
            }
            .searchable(text: $search, prompt: "Поиск")
            .navigationTitle("Магазин")
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        NavigationStack {
            List(store.history, id: \.self) { Text($0) }
                .navigationTitle("История")
        }
    }
}
