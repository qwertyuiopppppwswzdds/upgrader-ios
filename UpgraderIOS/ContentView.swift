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
    @Published var balance: Double = 1000
    @Published var history: [String] = []
    @Published var selectedInput: Skin?
    @Published var selectedTarget: Skin?
    @Published var chancePreset: Double = 50
    @Published var message = "Выбери предмет и цель"
    @Published var isSpinning = false
    @Published var result: Skin?
    @Published var didWin = false

    init() { load() }

    func load() {
        guard let url = Bundle.main.url(forResource: "skins_database", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Skin].self, from: data) else { return }
        skins = decoded
        let savedIDs = UserDefaults.standard.stringArray(forKey: "inventory") ?? []
        if !savedIDs.isEmpty {
            inventory = savedIDs.compactMap { id in decoded.first(where: { $0.id == id }) }
        } else {
            inventory = Array(decoded.prefix(8))
        }
        if let saved = UserDefaults.standard.object(forKey: "balance") as? Double { balance = saved }
    }

    var calculatedChance: Double {
        guard let a = selectedInput, let b = selectedTarget, b.price > 0 else { return 0 }
        return min(95, max(1, a.price / b.price * 100))
    }

    func spin() {
        guard let a = selectedInput, let b = selectedTarget, !isSpinning else { return }
        isSpinning = true; result = nil
        let chance = calculatedChance
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
            let win = Double.random(in: 0...100) <= chance
            self.didWin = win
            self.result = win ? b : a
            if win {
                self.inventory.removeAll { $0.id == a.id }
                self.inventory.append(b)
                self.message = "ПОБЕДА!"
                self.history.insert("✓ Выигрыш • \(b.name)", at: 0)
            } else {
                self.inventory.removeAll { $0.id == a.id }
                self.message = "ПРОИГРЫШ"
                self.history.insert("✕ Проигрыш • \(a.name)", at: 0)
            }
            self.isSpinning = false
            self.selectedInput = nil
            self.selectedTarget = nil
            self.save()
        }
    }

    func buy(_ skin: Skin) {
        guard balance >= skin.price else { return }
        balance -= skin.price; inventory.append(skin)
        history.insert("Покупка • \(skin.name)", at: 0); save()
    }

    func sell(_ skin: Skin) {
        balance += skin.price
        if let i = inventory.firstIndex(of: skin) { inventory.remove(at: i) }
        history.insert("Продажа • \(skin.name)", at: 0); save()
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
            UpgradeView().tabItem { Label("Апгрейд", systemImage: "bolt.fill") }
            InventoryView().tabItem { Label("Инвентарь", systemImage: "shippingbox.fill") }
            ShopView().tabItem { Label("Магазин", systemImage: "cart.fill") }
            HistoryView().tabItem { Label("История", systemImage: "clock.fill") }
        }
        .tint(.green)
        .preferredColorScheme(.dark)
    }
}

struct SkinCard: View {
    let skin: Skin
    var compact = false
    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: skin.imageUrl ?? "")) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName: "cube.transparent").foregroundStyle(.secondary) }
                .frame(width: compact ? 62 : 82, height: compact ? 48 : 62)
            VStack(alignment: .leading, spacing: 4) {
                Text(skin.name).font(compact ? .caption : .subheadline.weight(.semibold)).lineLimit(2)
                Text(skin.rarity).font(.caption2).foregroundStyle(rarityColor(skin.rarityColor))
                Text("$\(skin.price, specifier: "%.2f")").font(.caption.bold()).foregroundStyle(.green)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
    }
    func rarityColor(_ hex: String?) -> Color { Color(hex: hex ?? "#4b69ff") }
}

struct UpgradeView: View {
    @EnvironmentObject var store: GameStore
    @State private var showInput = false
    @State private var showTarget = false
    @State private var rotation = 0.0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    balanceBar
                    Text("UPGRADE").font(.system(size: 27, weight: .black)).tracking(2)
                    HStack(spacing: 12) {
                        selector(title: "ТВОЙ СКИН", skin: store.selectedInput) { showInput = true }
                        Image(systemName: "arrow.right").foregroundStyle(.green).font(.title2.bold())
                        selector(title: "ЦЕЛЬ", skin: store.selectedTarget) { showTarget = true }
                    }
                    chancePanel
                    RouletteWheel(spinning: store.isSpinning, rotation: $rotation)
                        .frame(height: 220)
                    if let result = store.result {
                        SkinCard(skin: result)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(store.didWin ? .green : .red, lineWidth: 2))
                    }
                    Button { withAnimation(.easeInOut(duration: 2.7)) { rotation += 1440 }; store.spin() } label: {
                        HStack { Image(systemName: store.isSpinning ? "hourglass" : "play.fill"); Text(store.isSpinning ? "КРУТИТСЯ..." : "АПГРЕЙД") }
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                    .disabled(store.selectedInput == nil || store.selectedTarget == nil || store.isSpinning)
                    Text(store.message).font(.headline).foregroundStyle(store.didWin ? .green : .secondary)
                }.padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Skin Upgrader")
            .sheet(isPresented: $showInput) { SkinPicker(title: "Выбери свой скин", items: store.inventory) { store.selectedInput = $0; showInput = false } }
            .sheet(isPresented: $showTarget) {
                let items = store.skins.filter { skin in guard let input = store.selectedInput else { return true }; return skin.price > input.price }
                SkinPicker(title: "Выбери цель", items: items) { store.selectedTarget = $0; showTarget = false }
            }
        }
    }
    var balanceBar: some View { HStack { Text("Баланс").foregroundStyle(.secondary); Spacer(); Text("$\(store.balance, specifier: "%.2f")").font(.headline).foregroundStyle(.green) }.padding().background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14)) }
    func selector(title: String, skin: Skin?, action: @escaping () -> Void) -> some View { Button(action: action) { VStack(spacing: 6) { Text(title).font(.caption2).foregroundStyle(.secondary); if let skin { SkinCard(skin: skin, compact: true) } else { RoundedRectangle(cornerRadius: 12).strokeBorder(.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5])).frame(height: 72).overlay(Image(systemName: "plus")) } } }.buttonStyle(.plain).frame(maxWidth: .infinity) }
    var chancePanel: some View { VStack(spacing: 8) { HStack { Text("Шанс"); Spacer(); Text("\(store.calculatedChance, specifier: "%.1f")%").font(.title3.bold()).foregroundStyle(.orange) }; HStack { ForEach([25.0, 50.0, 75.0, 90.0], id: \.self) { p in Button("\(Int(p))%") { store.chancePreset = p }.buttonStyle(.bordered).tint(store.chancePreset == p ? .orange : .gray) } } }.padding().background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14)) }
}

struct RouletteWheel: View {
    let spinning: Bool
    @Binding var rotation: Double
    let labels = ["MISS", "LOW", "WIN", "RARE", "MISS", "WIN", "LEGEND", "MISS"]
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.04)).overlay(Circle().stroke(.gray.opacity(0.35), lineWidth: 3))
            ForEach(0..<8, id: \.self) { i in
                Text(labels[i]).font(.system(size: 10, weight: .bold)).foregroundStyle(i == 2 || i == 5 ? .green : .secondary).offset(y: -78).rotationEffect(.degrees(Double(i) * 45))
            }
            Circle().stroke(.green.opacity(0.6), lineWidth: 8).padding(32)
            Image(systemName: "triangle.fill").font(.title).foregroundStyle(.green).offset(y: -94)
            Circle().fill(.black).frame(width: 58, height: 58).overlay(Text("SPIN").font(.caption.bold()))
        }.rotationEffect(.degrees(rotation)).animation(.easeOut(duration: 2.7), value: rotation)
    }
}

struct SkinPicker: View {
    let title: String; let items: [Skin]; let choose: (Skin) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var filtered: [Skin] { search.isEmpty ? Array(items.prefix(250)) : items.filter { $0.name.localizedCaseInsensitiveContains(search) }.prefix(250).map{$0} }
    var body: some View { NavigationStack { List(filtered) { skin in Button { choose(skin) } label: { SkinCard(skin: skin) }.buttonStyle(.plain) }.searchable(text: $search).navigationTitle(title).toolbar { Button("Готово") { dismiss() } } } }
}

struct InventoryView: View {
    @EnvironmentObject var store: GameStore
    var body: some View { NavigationStack { List(store.inventory) { skin in HStack { SkinCard(skin: skin); Button("Продать") { store.sell(skin) }.buttonStyle(.bordered) } }.navigationTitle("Инвентарь") } }
}

struct ShopView: View {
    @EnvironmentObject var store: GameStore
    @State private var search = ""
    var filtered: [Skin] { let q = search.lowercased(); return store.skins.filter { q.isEmpty || $0.name.lowercased().contains(q) }.prefix(300).map{$0} }
    var body: some View { NavigationStack { List(filtered) { skin in HStack { SkinCard(skin: skin, compact: true); Spacer(); Button("Купить") { store.buy(skin) } } }.searchable(text: $search).navigationTitle("Магазин") } }
}

struct HistoryView: View { @EnvironmentObject var store: GameStore; var body: some View { NavigationStack { List(store.history, id: \.self) { Text($0) }.navigationTitle("История") } } }

extension Color {
    init(hex: String) {
        let s = hex.replacingOccurrences(of: "#", with: "")
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 255)/255, green: Double((v >> 8) & 255)/255, blue: Double(v & 255)/255)
    }
}
