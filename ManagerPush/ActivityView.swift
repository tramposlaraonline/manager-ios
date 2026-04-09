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
            activityStatusBar
            activityFeed
        }
        .background(Color.mgBg)
        .onAppear {
            if dm.isPaired && !dm.deviceToken.isEmpty && vm.orders.isEmpty {
                vm.deviceToken = dm.deviceToken
                Task { await vm.loadFilters(); await vm.loadOrders() }
            }
        }
        .onReceive(dm.$deviceToken) { token in
            if dm.isPaired && !token.isEmpty && vm.orders.isEmpty {
                vm.deviceToken = token
                Task { await vm.loadFilters(); await vm.loadOrders() }
            }
        }
        .sheet(isPresented: $showCustomDate) {
            ActivityDateSheet(vm: vm, isPresented: $showCustomDate)
        }
        .sheet(item: $selectedOrder) { order in
            OrderDetailSheet(order: order)
        }
    }

    // MARK: - Toolbar

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
        .padding(.bottom, 10)
    }

    // MARK: - Status Bar

    private var activityStatusBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ActivityStatusTab(label: "Todas", filter: "all", icon: "list.bullet", count: nil, isActive: vm.selectedFilter == "all") {
                    vm.selectedFilter = "all"; Task { await vm.loadOrders() }
                }
                ActivityStatusTab(label: "Aprovadas", filter: "APPROVED", icon: "checkmark.circle", count: vm.statusCounts["APPROVED"], color: .mgGreen, isActive: vm.selectedFilter == "APPROVED") {
                    vm.selectedFilter = "APPROVED"; Task { await vm.loadOrders() }
                }
                ActivityStatusTab(label: "Pendentes", filter: "PENDING", icon: "clock", count: vm.statusCounts["PENDING"], color: .mgAmber, isActive: vm.selectedFilter == "PENDING") {
                    vm.selectedFilter = "PENDING"; Task { await vm.loadOrders() }
                }
                ActivityStatusTab(label: "Recusadas", filter: "REFUSED", icon: "xmark.circle", count: vm.statusCounts["REFUSED"], color: .mgRed, isActive: vm.selectedFilter == "REFUSED") {
                    vm.selectedFilter = "REFUSED"; Task { await vm.loadOrders() }
                }
                ActivityStatusTab(label: "Reembolsadas", filter: "REFUNDED", icon: "arrow.uturn.left.circle", count: vm.statusCounts["REFUNDED"], color: .mgRed, isActive: vm.selectedFilter == "REFUNDED") {
                    vm.selectedFilter = "REFUNDED"; Task { await vm.loadOrders() }
                }
                ActivityStatusTab(label: "Chargeback", filter: "CHARGEDBACK", icon: "exclamationmark.triangle", count: vm.statusCounts["CHARGEDBACK"], color: .mgRed, isActive: vm.selectedFilter == "CHARGEDBACK") {
                    vm.selectedFilter = "CHARGEDBACK"; Task { await vm.loadOrders() }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Feed

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

            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await vm.loadOrders() }
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

// MARK: - Period Grid (extracted for compiler)

struct ActivityPeriodGrid: View {
    @ObservedObject var vm: ActivityViewModel
    @Binding var showCustomDate: Bool

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 1) {
                pBtn("Hoje", .today)
                pBtn("Ontem", .yesterday)
                pBtn("Semana", .week)
                pBtn("Sem. passada", .lastweek)
            }
            HStack(spacing: 1) {
                pBtn("Mês", .month)
                pBtn("Mês passado", .lastmonth)
                pBtn("Tudo", .all)
                Button(action: { showCustomDate = true }) {
                    Text(vm.isCustomPeriod ? vm.periodDisplayLabel : "Período...")
                        .font(.system(size: 11, weight: vm.isCustomPeriod ? .semibold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundColor(vm.isCustomPeriod ? .white : .mgText2)
                        .background(vm.isCustomPeriod ? Color.mgAccent : Color.mgS2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mgBorder, lineWidth: 1))
    }

    private func pBtn(_ label: String, _ period: DashboardPeriod) -> some View {
        let active = vm.selectedPeriod == period && !vm.isCustomPeriod
        return Button(action: {
            vm.selectedPeriod = period; vm.isCustomPeriod = false
            Task { await vm.loadOrders() }
        }) {
            Text(label)
                .font(.system(size: 11, weight: active ? .semibold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundColor(active ? .white : .mgText2)
                .background(active ? Color.mgAccent : Color.mgS2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Row (extracted)

struct ActivityFilterRow: View {
    @ObservedObject var vm: ActivityViewModel

    var body: some View {
        HStack(spacing: 0) {
            chipMenu(label: "Conta de Anúncio", value: vm.selectedAccountName, items: vm.accountMenuItems)
            Rectangle().fill(Color.mgBorder).frame(width: 1, height: 32)
            chipMenu(label: "Produto", value: vm.selectedProductName, items: vm.productMenuItems)
        }
    }

    private func chipMenu(label: String, value: String, items: [MenuItem]) -> some View {
        Menu {
            ForEach(items, id: \.id) { item in
                Button(action: { item.action(); Task { await vm.loadOrders() } }) {
                    if item.name == value {
                        Label(item.name, systemImage: "checkmark")
                    } else {
                        Text(item.name)
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.mgText3)
                        .tracking(0.5)
                    Text(value)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.mgText2)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.mgText3)
                    .opacity(0.6)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Status Tab Button (extracted)

struct ActivityStatusTab: View {
    let label: String
    let filter: String
    let icon: String
    var count: Int?
    var color: Color = .mgText2
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.system(size: 10))
                    Text(label).font(.system(size: 10, weight: .medium))
                }
                if let c = count, c > 0 {
                    Text("\(c)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.mgAccent : Color.mgCard)
            .foregroundColor(isActive ? .white : .mgText3)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Color.clear : Color.mgBorder, lineWidth: 1))
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
                    .fill(order.statusColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: order.statusIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(order.statusColor)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(order.statusLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.mgText)
                    Spacer()
                    Text(order.timeFormatted)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.mgText3)
                }
                Text(order.valueFormatted)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(order.statusColor)
                if !order.detail.isEmpty {
                    Text(order.detail)
                        .font(.system(size: 10))
                        .foregroundColor(.mgText3)
                        .lineLimit(1)
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
                    row("Status", order.statusLabel, order.statusColor)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
            }
        }
    }

    private func row(_ label: String, _ value: String, _ color: Color = .primary) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(color).multilineTextAlignment(.trailing)
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
    @State private var validationError: String?

    private let brt = TimeZone(secondsFromGMT: -3 * 3600)!

    var body: some View {
        NavigationView {
            Form {
                Section("Período personalizado") {
                    DatePicker("De", selection: $fromDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, brt)
                    DatePicker("Até", selection: $toDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, brt)
                        .onChange(of: toDate) { newVal in
                            var c = Calendar.current; c.timeZone = brt
                            let nd = c.ordinality(of: .day, in: .era, for: newVal) ?? 0
                            guard nd != lastToDay else { return }
                            lastToDay = nd
                            if c.isDateInToday(newVal) {
                                let now = Date()
                                var comps = c.dateComponents([.year, .month, .day], from: newVal)
                                comps.hour = c.component(.hour, from: now)
                                comps.minute = c.component(.minute, from: now); comps.second = 0
                                if let a = c.date(from: comps) { toDate = a }
                            } else {
                                var comps = c.dateComponents([.year, .month, .day], from: newVal)
                                comps.hour = 23; comps.minute = 59; comps.second = 59
                                if let a = c.date(from: comps) { toDate = a }
                            }
                        }
                }
                if let err = validationError {
                    Section { Text(err).font(.system(size: 13)).foregroundColor(.mgRed) }
                }
            }
            .navigationTitle("Período")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        if fromDate >= toDate { validationError = "Data final deve ser posterior à inicial."; return }
                        let f = ISO8601DateFormatter(); f.timeZone = TimeZone(secondsFromGMT: 0)
                        vm.customFrom = f.string(from: fromDate); vm.customTo = f.string(from: toDate)
                        vm.isCustomPeriod = true; isPresented = false
                        Task { await vm.loadOrders() }
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
    @Published var customFrom: String = ""
    @Published var customTo: String = ""
    @Published var selectedProductId: String?
    @Published var selectedAccountId: String?
    @Published var products: [FilterItem] = []
    @Published var accounts: [FilterItem] = []
    @Published var orders: [ActivityOrder] = []
    @Published var statusCounts: [String: Int] = [:]
    @Published var selectedFilter: String = "all"
    @Published var isLoading = false

    var periodDisplayLabel: String {
        if isCustomPeriod {
            let fmt = DateFormatter(); fmt.dateFormat = "dd/MM"
            fmt.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
            let iso = ISO8601DateFormatter(); iso.timeZone = TimeZone(secondsFromGMT: 0)
            if let f = iso.date(from: customFrom), let t = iso.date(from: customTo) {
                return "\(fmt.string(from: f)) — \(fmt.string(from: t))"
            }
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
        let brt = TimeZone(secondsFromGMT: -3 * 3600)!
        var cal = Calendar.current; cal.timeZone = brt
        let todayStart = cal.startOfDay(for: Date())
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!
        let dateFmt = DateFormatter(); dateFmt.dateFormat = "dd/MM/yyyy"; dateFmt.timeZone = brt

        var dict: [String: (label: String, orders: [ActivityOrder], sort: Date)] = [:]
        for o in orders {
            let key: String; let label: String
            if o.date >= todayStart { key = "0_today"; label = "Hoje" }
            else if o.date >= yesterdayStart { key = "1_yesterday"; label = "Ontem" }
            else { let d = dateFmt.string(from: o.date); key = "2_\(d)"; label = d }
            if dict[key] == nil { dict[key] = (label, [], o.date) }
            dict[key]!.orders.append(o)
        }
        return dict.sorted { $0.key < $1.key }
            .map { OrderGroup(date: $0.key, label: $0.value.label, orders: $0.value.orders) }
    }

    private let baseURL = DeviceManager.shared.baseURL

    func loadFilters() async {
        guard let u1 = URL(string: "\(baseURL)/dashboard/products"),
              let u2 = URL(string: "\(baseURL)/dashboard/accounts") else { return }
        var r1 = URLRequest(url: u1); r1.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        var r2 = URLRequest(url: u2); r2.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        if let (d, _) = try? await URLSession.shared.data(for: r1),
           let i = try? JSONDecoder().decode([FilterItem].self, from: d) { products = i }
        if let (d, _) = try? await URLSession.shared.data(for: r2),
           let i = try? JSONDecoder().decode([FilterItem].self, from: d) { accounts = i }
    }

    func loadOrders() async {
        isLoading = true
        let from: String; let to: String
        if isCustomPeriod { from = customFrom; to = customTo }
        else { let r = selectedPeriod.dateRange; from = r.from; to = r.to }

        var url = "\(baseURL)/dashboard/orders?limit=50&from=\(from)&to=\(to)"
        if selectedFilter != "all" { url += "&status=\(selectedFilter)" }
        if let pid = selectedProductId { url += "&productIds=\(pid)" }

        guard let u = URL(string: url) else { isLoading = false; return }
        var req = URLRequest(url: u); req.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            isLoading = false; return
        }
        if let arr = json["orders"] as? [[String: Any]] { orders = arr.compactMap { ActivityOrder(json: $0) } }
        if let c = json["statusCounts"] as? [String: Int] { statusCounts = c }
        isLoading = false
    }
}

// MARK: - Models

struct OrderGroup: Identifiable {
    let date: String; let label: String; let orders: [ActivityOrder]
    var id: String { date }
}

struct ActivityOrder: Identifiable {
    let id: String
    let externalOrderId: String
    let status: String
    let grossAmountCents: Int
    let netAmountCents: Int
    let paymentMethod: String
    let productName: String
    let customerName: String
    let customerEmail: String
    let utmSource: String
    let utmCampaign: String
    let src: String
    let date: Date
    let approvedAt: Date?

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, let status = json["status"] as? String else { return nil }
        self.id = id
        self.externalOrderId = json["externalOrderId"] as? String ?? ""
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
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.date = (json["orderCreatedAt"] as? String).flatMap { iso.date(from: $0) } ?? Date()
        self.approvedAt = (json["approvedAt"] as? String).flatMap { iso.date(from: $0) }
    }

    var statusLabel: String {
        switch status {
        case "APPROVED": return "Venda aprovada"
        case "PENDING": return "Venda pendente"
        case "REFUSED": return "Venda recusada"
        case "REFUNDED": return "Venda reembolsada"
        case "CHARGEDBACK": return "Chargeback"
        default: return "Venda"
        }
    }

    var statusIcon: String {
        switch status {
        case "APPROVED": return "checkmark.circle.fill"
        case "PENDING": return "clock.fill"
        case "REFUSED": return "xmark.circle.fill"
        case "REFUNDED": return "arrow.uturn.left.circle.fill"
        case "CHARGEDBACK": return "exclamationmark.triangle.fill"
        default: return "circle.fill"
        }
    }

    var statusColor: Color {
        switch status {
        case "APPROVED": return .mgGreen
        case "PENDING": return .mgAmber
        default: return .mgRed
        }
    }

    private func cur(_ cents: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "BRL"
        f.locale = Locale(identifier: "pt_BR"); f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "R$ 0,00"
    }

    var valueFormatted: String { cur(grossAmountCents) }
    var netValueFormatted: String { cur(netAmountCents) }

    var timeFormatted: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
        return f.string(from: date)
    }
    var fullDateFormatted: String {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm"; f.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
        return f.string(from: date)
    }
    var approvedDateFormatted: String? {
        guard let d = approvedAt else { return nil }
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm"; f.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
        return f.string(from: d)
    }

    var detail: String {
        [productName, paymentMethod.uppercased(), utmCampaign].filter { !$0.isEmpty }.joined(separator: " • ")
    }
}
