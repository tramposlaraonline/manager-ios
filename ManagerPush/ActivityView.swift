import SwiftUI
import Combine
import UIKit

// MARK: - Activity View

struct ActivityView: View {
    @StateObject private var vm = ActivityViewModel()
    @StateObject private var dm = DeviceManager.shared
    @State private var showCustomDate = false
    @State private var selectedOrder: ActivityOrder?

    var body: some View {
        VStack(spacing: 0) {
            activityToolbar

            // Status text
            HStack {
                Spacer()
                Text(vm.statusText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(vm.isLoading ? .mgText3.opacity(0.6) : .mgText3.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
            .opacity(vm.statusText.isEmpty ? 0 : 1)

            // Status filter chips
            activityStatusBar

            // Feed
            activityFeed
        }
        .background(Color.mgBg)
        .onAppear {
            if dm.isPaired && !dm.deviceToken.isEmpty && vm.orders.isEmpty {
                vm.deviceToken = dm.deviceToken
                Task { await vm.loadFilters(); await vm.loadOrders(reset: true) }
            }
        }
        .onReceive(dm.$deviceToken) { token in
            if dm.isPaired && !token.isEmpty && vm.orders.isEmpty {
                vm.deviceToken = token
                Task { await vm.loadFilters(); await vm.loadOrders(reset: true) }
            }
        }
        .sheet(isPresented: $showCustomDate) {
            ActivityDateSheet(vm: vm, isPresented: $showCustomDate)
        }
        .sheet(item: $selectedOrder) { order in
            OrderDetailSheet(order: order)
        }
    }

    private var activityToolbar: some View {
        VStack(spacing: 0) {
            ActivityPeriodGrid(vm: vm, showCustomDate: $showCustomDate)
                .padding(.bottom, 12)
            Rectangle().fill(Color.mgBorder).frame(height: 1)
            ActivityFilterRow(vm: vm)
                .padding(.top, 10)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(Color.mgCard)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mgBorder, lineWidth: 1))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var activityStatusBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                sChip("Todas", "all", nil)
                sDot
                sChip("Aprovadas", "APPROVED", vm.statusCounts["APPROVED"])
                sDot
                sChip("Pendentes", "PENDING", vm.statusCounts["PENDING"])
                sDot
                sChip("Recusadas", "REFUSED", vm.statusCounts["REFUSED"])
                sDot
                sChip("Reembolsos", "REFUNDED", vm.statusCounts["REFUNDED"])
                sDot
                sChip("Chargeback", "CHARGEDBACK", vm.statusCounts["CHARGEDBACK"])
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 6)
    }

    private var sDot: some View {
        Text("·").font(.system(size: 14)).foregroundColor(.mgBorder).padding(.horizontal, 2)
    }

    private func sChip(_ label: String, _ filter: String, _ count: Int?) -> some View {
        let active = vm.selectedFilter == filter
        return Button(action: {
            vm.selectedFilter = filter
            Task { await vm.loadOrders(reset: true) }
        }) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 11, weight: active ? .semibold : .regular))
                if let c = count, c > 0 {
                    Text("\(c)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(active ? .mgAccent : .mgText3)
                }
            }
            .foregroundColor(active ? .mgText : .mgText3)
        }
        .buttonStyle(.plain)
    }

    private var activityFeed: some View {
        List {
            ForEach(vm.groupedOrders, id: \.date) { group in
                Section {
                    ForEach(group.orders, id: \.id) { order in
                        OrderCard(order: order)
                            .onTapGesture { selectedOrder = order }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    Text(group.label)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.mgText3)
                        .textCase(.uppercase)
                }
            }

            if vm.orders.isEmpty && !vm.isLoading {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // Loading / load more
            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else if vm.hasMore {
                Color.clear.frame(height: 1)
                    .onAppear { Task { await vm.loadMore() } }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await vm.loadOrders(reset: true) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.mgText3)
            Text("Nenhuma venda encontrada")
                .font(.system(size: 13))
                .foregroundColor(.mgText3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Period Grid

struct ActivityPeriodGrid: View {
    @ObservedObject var vm: ActivityViewModel
    @Binding var showCustomDate: Bool

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 1) {
                pBtn("Hoje", .today); pBtn("Ontem", .yesterday)
                pBtn("Semana", .week); pBtn("Sem. passada", .lastweek)
            }
            HStack(spacing: 1) {
                pBtn("Mês", .month); pBtn("Mês passado", .lastmonth); pBtn("Tudo", .all)
                Button(action: { showCustomDate = true }) {
                    Text(vm.isCustomPeriod ? vm.periodDisplayLabel : "Período...")
                        .font(.system(size: 11, weight: vm.isCustomPeriod ? .semibold : .medium))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .foregroundColor(vm.isCustomPeriod ? .white : .mgText2)
                        .background(vm.isCustomPeriod ? Color.mgAccent : Color.mgS2)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mgBorder, lineWidth: 1))
    }

    private func pBtn(_ label: String, _ p: DashboardPeriod) -> some View {
        let on = vm.selectedPeriod == p && !vm.isCustomPeriod
        return Button(action: {
            vm.selectedPeriod = p; vm.isCustomPeriod = false
            Task { await vm.loadOrders(reset: true) }
        }) {
            Text(label).font(.system(size: 11, weight: on ? .semibold : .medium))
                .frame(maxWidth: .infinity).padding(.vertical, 7)
                .foregroundColor(on ? .white : .mgText2)
                .background(on ? Color.mgAccent : Color.mgS2)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

// MARK: - Filter Row

struct ActivityFilterRow: View {
    @ObservedObject var vm: ActivityViewModel

    var body: some View {
        HStack(spacing: 0) {
            chip("Conta de Anúncio", vm.selectedAccountName, vm.accountMenuItems)
            Rectangle().fill(Color.mgBorder).frame(width: 1, height: 32)
            chip("Produto", vm.selectedProductName, vm.productMenuItems)
        }
    }

    private func chip(_ label: String, _ value: String, _ items: [MenuItem]) -> some View {
        Menu {
            ForEach(items, id: \.id) { item in
                Button(action: { item.action(); Task { await vm.loadOrders(reset: true) } }) {
                    if item.name == value { Label(item.name, systemImage: "checkmark") }
                    else { Text(item.name) }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label.uppercased()).font(.system(size: 9, weight: .medium)).foregroundColor(.mgText3).tracking(0.5)
                    Text(value).font(.system(size: 11.5, weight: .medium)).foregroundColor(.mgText2)
                }
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).foregroundColor(.mgText3).opacity(0.6)
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Order Card

struct OrderCard: View {
    let order: ActivityOrder

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(order.iconBgColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: order.statusIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(order.iconBgColor)
            }.padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(order.statusLabel).font(.system(size: 12, weight: .semibold)).foregroundColor(.mgText)
                    Spacer()
                    Text(order.timeFormatted).font(.system(size: 10, design: .monospaced)).foregroundColor(.mgText3)
                }
                Text(order.valueFormatted)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(order.valueColor)
                if !order.detail.isEmpty {
                    Text(order.detail).font(.system(size: 10)).foregroundColor(.mgText3).lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(Color.mgCard)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.mgBorder, lineWidth: 1))
    }
}

// MARK: - Order Detail Sheet

struct OrderDetailSheet: View {
    let order: ActivityOrder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Venda") {
                    row("Status", order.statusLabel, order.valueColor)
                    row("Valor bruto", order.valueFormatted)
                    if order.netAmountCents > 0 { row("Valor líquido", order.netValueFormatted) }
                }
                Section("Detalhes") {
                    row("Produto", order.productName.isEmpty ? "—" : order.productName)
                    row("Pagamento", order.paymentMethod.isEmpty ? "—" : order.paymentMethod.uppercased())
                }
                Section("Cliente") {
                    row("Cliente", order.customerName.isEmpty ? "—" : order.customerName)
                    row("Email", order.customerEmail.isEmpty ? "—" : order.customerEmail)
                }
                Section("Atribuição") {
                    row("Campanha", order.utmCampaign.isEmpty ? "—" : order.utmCampaign)
                    row("Fonte", order.utmSource.isEmpty ? "—" : order.utmSource)
                    row("Origem", order.src.isEmpty ? "—" : order.src)
                }
                Section("Informações") {
                    row("Criado em", order.fullDateFormatted)
                    if let a = order.approvedDateFormatted { row("Aprovado em", a) }
                    row("ID externo", order.externalOrderId.isEmpty ? "—" : order.externalOrderId)
                }
            }
            .navigationTitle("Detalhes da Venda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
        }
    }

    private func row(_ l: String, _ v: String, _ c: Color = .primary) -> some View {
        HStack {
            Text(l).font(.system(size: 13)).foregroundColor(.secondary)
            Spacer()
            Text(v).font(.system(size: 13, weight: .medium)).foregroundColor(c).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Activity Date Sheet

struct ActivityDateSheet: View {
    @ObservedObject var vm: ActivityViewModel
    @Binding var isPresented: Bool
    @State private var fromDate = Date()
    @State private var toDate = Date()
    @State private var lastToDay: Int = 0
    @State private var err: String?
    private let brt = TimeZone(secondsFromGMT: -3 * 3600)!

    var body: some View {
        NavigationView {
            Form {
                Section("Período personalizado") {
                    DatePicker("De", selection: $fromDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute]).environment(\.timeZone, brt)
                    DatePicker("Até", selection: $toDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute]).environment(\.timeZone, brt)
                        .onChange(of: toDate) { nv in
                            var c = Calendar.current; c.timeZone = brt
                            let nd = c.ordinality(of: .day, in: .era, for: nv) ?? 0
                            guard nd != lastToDay else { return }; lastToDay = nd
                            if c.isDateInToday(nv) {
                                var cp = c.dateComponents([.year,.month,.day], from: nv)
                                cp.hour = c.component(.hour, from: Date()); cp.minute = c.component(.minute, from: Date()); cp.second = 0
                                if let a = c.date(from: cp) { toDate = a }
                            } else {
                                var cp = c.dateComponents([.year,.month,.day], from: nv)
                                cp.hour = 23; cp.minute = 59; cp.second = 59
                                if let a = c.date(from: cp) { toDate = a }
                            }
                        }
                }
                if let e = err { Section { Text(e).font(.system(size: 13)).foregroundColor(.mgRed) } }
            }
            .navigationTitle("Período").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        if fromDate >= toDate { err = "Data final deve ser posterior à inicial."; return }
                        let f = ISO8601DateFormatter(); f.timeZone = TimeZone(secondsFromGMT: 0)
                        vm.customFrom = f.string(from: fromDate); vm.customTo = f.string(from: toDate)
                        vm.isCustomPeriod = true; isPresented = false
                        Task { await vm.loadOrders(reset: true) }
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            var c = Calendar.current; c.timeZone = brt
            fromDate = c.startOfDay(for: Date()); toDate = Date()
            lastToDay = c.ordinality(of: .day, in: .era, for: toDate) ?? 0
        }
    }
}

// MARK: - View Model

@MainActor
class ActivityViewModel: ObservableObject {
    var deviceToken: String = ""
    @Published var selectedPeriod: DashboardPeriod = .today
    @Published var isCustomPeriod = false
    @Published var customFrom = ""
    @Published var customTo = ""
    @Published var selectedProductId: String?
    @Published var selectedAccountId: String?
    @Published var products: [FilterItem] = []
    @Published var accounts: [FilterItem] = []
    @Published var orders: [ActivityOrder] = []
    @Published var statusCounts: [String: Int] = [:]
    @Published var selectedFilter = "all"
    @Published var isLoading = false
    @Published var hasMore = false
    @Published var lastUpdated: String?

    var statusText: String {
        if isLoading { return "carregando..." }
        if let ts = lastUpdated { return "atualizado às \(ts)" }
        return ""
    }

    var periodDisplayLabel: String {
        if isCustomPeriod {
            let fmt = DateFormatter(); fmt.dateFormat = "dd/MM"; fmt.timeZone = TimeZone(secondsFromGMT: -3*3600)
            let iso = ISO8601DateFormatter(); iso.timeZone = TimeZone(secondsFromGMT: 0)
            if let f = iso.date(from: customFrom), let t = iso.date(from: customTo) { return "\(fmt.string(from: f)) — \(fmt.string(from: t))" }
            return "Custom"
        }
        return selectedPeriod.label
    }

    var selectedAccountName: String {
        if let id = selectedAccountId, let a = accounts.first(where: { $0.id == id }) { return a.name }
        return "Todas"
    }
    var selectedProductName: String {
        if let id = selectedProductId, let p = products.first(where: { $0.id == id }) { return p.name }
        return "Todos"
    }
    var accountMenuItems: [MenuItem] {
        var r = [MenuItem(id: "all", name: "Todas") { [weak self] in self?.selectedAccountId = nil }]
        r += accounts.map { a in MenuItem(id: a.id, name: a.name) { [weak self] in self?.selectedAccountId = a.id } }
        return r
    }
    var productMenuItems: [MenuItem] {
        var r = [MenuItem(id: "all", name: "Todos") { [weak self] in self?.selectedProductId = nil }]
        r += products.map { p in MenuItem(id: p.id, name: p.name) { [weak self] in self?.selectedProductId = p.id } }
        return r
    }

    var groupedOrders: [OrderGroup] {
        let brt = TimeZone(secondsFromGMT: -3*3600)!
        var cal = Calendar.current; cal.timeZone = brt
        let ts = cal.startOfDay(for: Date())
        let ys = cal.date(byAdding: .day, value: -1, to: ts)!
        let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"; df.timeZone = brt
        var d: [String: (String, [ActivityOrder], Date)] = [:]
        for o in orders {
            let k: String; let l: String
            if o.date >= ts { k = "0"; l = "Hoje" }
            else if o.date >= ys { k = "1"; l = "Ontem" }
            else { let s = df.string(from: o.date); k = "2_\(s)"; l = s }
            if d[k] == nil { d[k] = (l, [], o.date) }
            d[k]!.1.append(o)
        }
        return d.sorted { $0.key < $1.key }.map { OrderGroup(date: $0.key, label: $0.value.0, orders: $0.value.1) }
    }

    private let baseURL = DeviceManager.shared.baseURL
    private let pageSize = 30

    func loadFilters() async {
        guard let u1 = URL(string: "\(baseURL)/dashboard/products"),
              let u2 = URL(string: "\(baseURL)/dashboard/accounts") else { return }
        var r1 = URLRequest(url: u1); r1.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        var r2 = URLRequest(url: u2); r2.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        if let (d,_) = try? await URLSession.shared.data(for: r1), let i = try? JSONDecoder().decode([FilterItem].self, from: d) { products = i }
        if let (d,_) = try? await URLSession.shared.data(for: r2), let i = try? JSONDecoder().decode([FilterItem].self, from: d) { accounts = i }
    }

    func loadOrders(reset: Bool) async {
        if reset { orders = []; hasMore = false }
        isLoading = true
        let from: String; let to: String
        if isCustomPeriod { from = customFrom; to = customTo }
        else { let r = selectedPeriod.dateRange; from = r.from; to = r.to }

        var url = "\(baseURL)/dashboard/orders?limit=\(pageSize)&offset=\(reset ? 0 : orders.count)&from=\(from)&to=\(to)"
        if selectedFilter != "all" { url += "&status=\(selectedFilter)" }
        if let pid = selectedProductId { url += "&productIds=\(pid)" }

        guard let u = URL(string: url) else { isLoading = false; return }
        var req = URLRequest(url: u); req.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { isLoading = false; return }

        if let arr = json["orders"] as? [[String: Any]] {
            let new = arr.compactMap { ActivityOrder(json: $0) }
            if reset { orders = new } else { orders.append(contentsOf: new) }
        }
        if let c = json["statusCounts"] as? [String: Int] { statusCounts = c }
        hasMore = json["hasMore"] as? Bool ?? false

        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm:ss"; fmt.timeZone = TimeZone(secondsFromGMT: -3*3600)
        lastUpdated = fmt.string(from: Date())
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading && hasMore else { return }
        await loadOrders(reset: false)
    }
}

// MARK: - Models

struct OrderGroup: Identifiable {
    let date: String; let label: String; let orders: [ActivityOrder]
    var id: String { date }
}

struct ActivityOrder: Identifiable {
    let id, externalOrderId, status: String
    let grossAmountCents, netAmountCents: Int
    let paymentMethod, productName, customerName, customerEmail, utmSource, utmCampaign, src: String
    let date: Date; let approvedAt: Date?

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, let status = json["status"] as? String else { return nil }
        self.id = id; self.externalOrderId = json["externalOrderId"] as? String ?? ""
        self.status = status
        self.grossAmountCents = json["grossAmountCents"] as? Int ?? 0
        self.netAmountCents = json["netAmountCents"] as? Int ?? 0
        self.paymentMethod = json["paymentMethod"] as? String ?? ""
        self.productName = json["productName"] as? String ?? ""
        self.customerName = json["customerName"] as? String ?? ""
        self.customerEmail = json["customerEmail"] as? String ?? ""
        self.utmSource = json["utmSource"] as? String ?? ""
        self.utmCampaign = json["utmCampaign"] as? String ?? ""
        self.src = json["src"] as? String ?? ""
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.date = (json["orderCreatedAt"] as? String).flatMap { iso.date(from: $0) } ?? Date()
        self.approvedAt = (json["approvedAt"] as? String).flatMap { iso.date(from: $0) }
    }

    var statusLabel: String {
        switch status {
        case "APPROVED": return "Venda aprovada"; case "PENDING": return "Venda pendente"
        case "REFUSED": return "Venda recusada"; case "REFUNDED": return "Venda reembolsada"
        case "CHARGEDBACK": return "Chargeback"; default: return "Venda"
        }
    }
    var statusIcon: String {
        switch status {
        case "APPROVED": return "checkmark.circle.fill"; case "PENDING": return "clock.fill"
        case "REFUSED": return "xmark.circle.fill"; case "REFUNDED": return "arrow.uturn.left.circle.fill"
        case "CHARGEDBACK": return "exclamationmark.triangle.fill"; default: return "circle.fill"
        }
    }
    // Icon background color
    var iconBgColor: Color {
        switch status {
        case "APPROVED": return .mgGreen; case "PENDING": return .mgText3
        default: return .mgRed
        }
    }
    // Value text color
    var valueColor: Color {
        switch status {
        case "APPROVED": return .mgGreen; case "PENDING": return .mgText
        default: return .mgRed
        }
    }

    private func cur(_ c: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "BRL"
        f.locale = Locale(identifier: "pt_BR"); f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: Double(c)/100)) ?? "R$ 0,00"
    }
    var valueFormatted: String { cur(grossAmountCents) }
    var netValueFormatted: String { cur(netAmountCents) }
    var timeFormatted: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(secondsFromGMT: -3*3600); return f.string(from: date)
    }
    var fullDateFormatted: String {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm"; f.timeZone = TimeZone(secondsFromGMT: -3*3600); return f.string(from: date)
    }
    var approvedDateFormatted: String? {
        guard let d = approvedAt else { return nil }
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm"; f.timeZone = TimeZone(secondsFromGMT: -3*3600); return f.string(from: d)
    }
    var detail: String { [productName, paymentMethod.uppercased(), utmCampaign].filter { !$0.isEmpty }.joined(separator: " • ") }
}
