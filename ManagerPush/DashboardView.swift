import SwiftUI
import Combine
import UIKit

// MARK: - Color Constants

extension Color {
    static let mgBg = Color(red: 13/255, green: 15/255, blue: 24/255)
    static let mgCard = Color(red: 18/255, green: 21/255, blue: 31/255)
    static let mgBorder = Color(red: 37/255, green: 40/255, blue: 64/255)
    static let mgAccent = Color(red: 108/255, green: 92/255, blue: 231/255)
    static let mgText = Color(red: 221/255, green: 225/255, blue: 245/255)
    static let mgText2 = Color(red: 122/255, green: 128/255, blue: 164/255)
    static let mgText3 = Color(red: 92/255, green: 100/255, blue: 144/255)
    static let mgGreen = Color(red: 0/255, green: 200/255, blue: 150/255)
    static let mgAmber = Color(red: 244/255, green: 169/255, blue: 53/255)
    static let mgRed = Color(red: 224/255, green: 108/255, blue: 117/255)
}

// MARK: - Dashboard View

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()
    @StateObject private var dm = DeviceManager.shared
    @State private var showCustomDate = false

    var body: some View {
        VStack(spacing: 0) {
            // Fixed toolbar
            toolbarSection
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // Timestamp row between toolbar and metrics
            HStack {
                Spacer()
                Text(vm.statusText)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(vm.isLoading ? .mgText3.opacity(0.6) : .mgText3.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
            .opacity(vm.statusText.isEmpty ? 0 : 1)

            // Scrollable metrics
            List {
                metricsContent
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await vm.loadSummary() }
        }
        .background(Color.mgBg)
        .onAppear {
            vm.setupAutoRefresh()
            if dm.isPaired && !dm.deviceToken.isEmpty {
                vm.deviceToken = dm.deviceToken
                Task {
                    await vm.loadFilters()
                    await vm.loadSummary()
                    if vm.periodIncludesToday { vm.startAutoRefresh() }
                }
            }
        }
        .onReceive(dm.$deviceToken) { token in
            if dm.isPaired && !token.isEmpty && vm.summary == nil {
                vm.deviceToken = token
                Task {
                    await vm.loadFilters()
                    await vm.loadSummary()
                    if vm.periodIncludesToday { vm.startAutoRefresh() }
                }
            }
        }
        .sheet(isPresented: $showCustomDate) {
            CustomDateSheet(vm: vm, isPresented: $showCustomDate)
        }
    }

    // MARK: - Toolbar

    private var toolbarSection: some View {
        VStack(spacing: 0) {
            // Period selector — segmented style
            VStack(spacing: 8) {
                // Row 1: main periods
                HStack(spacing: 0) {
                    ForEach([DashboardPeriod.today, .yesterday, .week, .lastweek], id: \.self) { period in
                        segmentButton(period.label, isActive: vm.selectedPeriod == period && !vm.isCustomPeriod) {
                            vm.selectedPeriod = period; vm.isCustomPeriod = false
                            Task { await vm.loadSummary() }
                            if vm.periodIncludesToday { vm.startAutoRefresh() } else { vm.stopAutoRefresh() }
                        }
                    }
                }
                // Row 2: remaining + custom
                HStack(spacing: 0) {
                    ForEach([DashboardPeriod.month, .lastmonth, .all], id: \.self) { period in
                        segmentButton(period.label, isActive: vm.selectedPeriod == period && !vm.isCustomPeriod) {
                            vm.selectedPeriod = period; vm.isCustomPeriod = false
                            Task { await vm.loadSummary() }
                            if vm.periodIncludesToday { vm.startAutoRefresh() } else { vm.stopAutoRefresh() }
                        }
                    }
                    segmentButton(
                        vm.isCustomPeriod ? vm.periodDisplayLabel : "Período...",
                        isActive: vm.isCustomPeriod
                    ) {
                        showCustomDate = true
                    }
                }
            }
            .padding(.bottom, 10)

            Rectangle().fill(Color.mgBorder).frame(height: 1)

            // Filters + timestamp
            HStack(spacing: 0) {
                filterChip(label: "Conta", value: vm.selectedAccountName, items: vm.accountMenuItems)
                Rectangle().fill(Color.mgBorder).frame(width: 1, height: 32)
                filterChip(label: "Produto", value: vm.selectedProductName, items: vm.productMenuItems)
            }
            .padding(.top, 10)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.mgCard)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mgBorder, lineWidth: 1))
        )
    }

    private func segmentButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isActive ? Color.mgAccent : Color.clear)
                .foregroundColor(isActive ? .white : .mgText3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(isActive ? 0 : 0.03))
        .overlay(
            Rectangle().stroke(Color.mgBorder.opacity(0.5), lineWidth: 0.5)
        )
    }

    private func filterChip(label: String, value: String, items: [MenuItem]) -> some View {
        Menu {
            ForEach(items, id: \.id) { item in
                Button(action: { item.action(); Task { await vm.loadSummary() } }) {
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

    // MARK: - Metrics

    private var metricsContent: some View {
        ZStack {
            if let s = vm.summary {
                let w = UIScreen.main.bounds.width - 32
                VStack(spacing: 14) {
                    MetricCard(label: "Gastos com Anúncios", value: s.spendFormatted)
                    MetricCard(label: "Faturamento Bruto", value: s.grossRevenueFormatted)
                    MetricCard(label: "Faturamento Líquido", value: s.netRevenueFormatted)
                    MetricCard(label: "Lucro", value: s.profitFormatted, valueColor: s.profitColor)

                    HStack(spacing: 10) {
                        MetricCard(label: "ROAS", value: s.roasFormatted, valueColor: s.roasColor, valueSize: 19)
                        MetricCard(label: "ROI", value: s.roiFormatted, valueColor: s.roiColor, valueSize: 19)
                        MetricCard(label: "Margem", value: s.marginFormatted, valueColor: s.marginColor, valueSize: 19)
                    }

                    MetricCard(label: "Vendas Pendentes", value: s.pendingRevenueFormatted)

                    HStack(spacing: 10) {
                        MetricCard(label: "Vendas Reembolsadas", value: s.refundedRevenueFormatted)
                            .frame(width: (w - 10) * 0.7)
                        MetricCard(label: "Reembolso", value: s.refundRateFormatted)
                            .frame(width: (w - 10) * 0.3)
                    }
                    HStack(spacing: 10) {
                        MetricCard(label: "Vendas Chargeback", value: s.chargedbackRevenueFormatted)
                            .frame(width: (w - 10) * 0.7)
                        MetricCard(label: "Chargeback", value: s.chargebackRateFormatted)
                            .frame(width: (w - 10) * 0.3)
                    }
                    MetricCard(label: "Vendas Devolvidas", value: s.returnedRevenueFormatted)

                    HStack(spacing: 10) {
                        MetricCard(label: "Custos de Produto", value: s.productCostsFormatted)
                        MetricCard(label: "Despesas Adicionais", value: s.additionalExpensesFormatted)
                    }

                    HStack(spacing: 10) {
                        MetricCard(label: "ARPU", value: s.arpuFormatted, valueSize: 17)
                        MetricCard(label: "CPA", value: s.cpaFormatted, valueSize: 17)
                    }
                    HStack(spacing: 10) {
                        MetricCard(label: "Leads", value: s.leadsFormatted, valueSize: 17)
                        MetricCard(label: "Custo por Lead", value: s.costPerLeadFormatted, valueSize: 17)
                    }
                    HStack(spacing: 10) {
                        MetricCard(label: "Imp. sobre Vendas", value: s.salesTaxFormatted, valueSize: 17)
                        MetricCard(label: "Imp. Total", value: s.totalTaxFormatted, valueSize: 17)
                    }
                    HStack(spacing: 10) {
                        MetricCard(label: "Imp. Meta Ads", value: s.metaAdsTaxFormatted, valueSize: 17)
                        MetricCard(label: "Taxas", value: s.feesFormatted, valueSize: 17)
                    }
                    HStack(spacing: 10) {
                        MetricCard(label: "Conversas", value: s.conversationsFormatted, valueSize: 17)
                        MetricCard(label: "Custo por Conversa", value: s.costPerConversationFormatted, valueSize: 17)
                    }
                }
                .opacity(vm.isLoading ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: vm.isLoading)
            }

            if vm.isLoading {
                ProgressView()
                    .tint(.mgAccent)
                    .scaleEffect(1.2)
                    .padding(.top, vm.summary == nil ? 60 : 0)
            }
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Custom Date Sheet

struct CustomDateSheet: View {
    @ObservedObject var vm: DashboardViewModel
    @Binding var isPresented: Bool
    @State private var fromDate = Date()
    @State private var toDate = Date()
    @State private var lastToDay: Int = 0
    @State private var validationError: String?

    private let brt = TimeZone(secondsFromGMT: -3 * 3600)!

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("De", selection: $fromDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, brt)
                    DatePicker("Até", selection: $toDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, brt)
                        .onChange(of: toDate) { newVal in
                            var calBRT = Calendar.current
                            calBRT.timeZone = brt
                            let newDay = calBRT.ordinality(of: .day, in: .era, for: newVal) ?? 0
                            guard newDay != lastToDay else { return }
                            lastToDay = newDay
                            if calBRT.isDateInToday(newVal) {
                                let now = Date()
                                var comps = calBRT.dateComponents([.year, .month, .day], from: newVal)
                                comps.hour = calBRT.component(.hour, from: now)
                                comps.minute = calBRT.component(.minute, from: now)
                                comps.second = 0
                                if let adj = calBRT.date(from: comps) { toDate = adj }
                            } else {
                                var comps = calBRT.dateComponents([.year, .month, .day], from: newVal)
                                comps.hour = 23; comps.minute = 59; comps.second = 59
                                if let adj = calBRT.date(from: comps) { toDate = adj }
                            }
                        }
                } header: { Text("Período personalizado") }

                if let err = validationError {
                    Section {
                        Text(err).font(.system(size: 13)).foregroundColor(.mgRed)
                    }
                }
            }
            .navigationTitle("Período")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        if fromDate >= toDate {
                            validationError = "A data final deve ser posterior à data inicial."
                            return
                        }
                        let fmt = ISO8601DateFormatter()
                        fmt.timeZone = TimeZone(secondsFromGMT: 0)
                        vm.customFrom = fmt.string(from: fromDate)
                        vm.customTo = fmt.string(from: toDate)
                        vm.isCustomPeriod = true
                        isPresented = false
                        Task { await vm.loadSummary() }
                        vm.stopAutoRefresh() // custom periods don't auto-refresh
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            var calBRT = Calendar.current
            calBRT.timeZone = brt
            fromDate = calBRT.startOfDay(for: Date())
            toDate = Date()
            lastToDay = calBRT.ordinality(of: .day, in: .era, for: toDate) ?? 0
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let label: String
    let value: String
    var valueColor: Color = .mgText
    var valueSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(.mgText2)
                .tracking(1)
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 9).fill(Color.mgCard)
                RoundedRectangle(cornerRadius: 9).stroke(Color.mgBorder, lineWidth: 1)
                LinearGradient(
                    gradient: Gradient(colors: [Color.mgAccent.opacity(0.6), Color.clear]),
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        )
    }
}

// MARK: - Period Enum

enum DashboardPeriod: CaseIterable {
    case today, yesterday, week, lastweek, month, lastmonth, all

    var label: String {
        switch self {
        case .today: return "Hoje"
        case .yesterday: return "Ontem"
        case .week: return "Semana"
        case .lastweek: return "Sem. passada"
        case .month: return "Mês"
        case .lastmonth: return "Mês passado"
        case .all: return "Tudo"
        }
    }

    var dateRange: (from: String, to: String) {
        let brt = TimeZone(secondsFromGMT: -3 * 3600)!
        var calBRT = Calendar.current
        calBRT.timeZone = brt
        let now = Date()
        let todayStart = calBRT.startOfDay(for: now)
        let day: TimeInterval = 86400
        let from: Date; let to: Date
        switch self {
        case .today:
            from = todayStart; to = Date(timeInterval: day - 1, since: todayStart)
        case .yesterday:
            from = Date(timeInterval: -day, since: todayStart); to = Date(timeInterval: -1, since: todayStart)
        case .week:
            let wd = calBRT.component(.weekday, from: todayStart)
            from = calBRT.date(byAdding: .day, value: -(wd - 1), to: todayStart)!
            to = Date(timeInterval: 7 * day - 1, since: from)
        case .lastweek:
            let wd = calBRT.component(.weekday, from: todayStart)
            from = calBRT.date(byAdding: .day, value: -(wd - 1 + 7), to: todayStart)!
            to = Date(timeInterval: 7 * day - 1, since: from)
        case .month:
            var c = calBRT.dateComponents([.year, .month], from: now)
            c.day = 1; c.hour = 0; c.minute = 0; c.second = 0
            from = calBRT.date(from: c)!; to = Date(timeInterval: day - 1, since: todayStart)
        case .lastmonth:
            var c = calBRT.dateComponents([.year, .month], from: now)
            c.month! -= 1; c.day = 1; c.hour = 0; c.minute = 0; c.second = 0
            from = calBRT.date(from: c)!
            var e = calBRT.dateComponents([.year, .month], from: now)
            e.day = 1; e.hour = 0; e.minute = 0; e.second = 0
            to = Date(timeInterval: -1, since: calBRT.date(from: e)!)
        case .all:
            let f = ISO8601DateFormatter(); f.timeZone = TimeZone(secondsFromGMT: 0)
            from = f.date(from: "2020-01-01T03:00:00Z")!
            to = Date(timeInterval: day - 1, since: todayStart)
        }
        let fmt = ISO8601DateFormatter(); fmt.timeZone = TimeZone(secondsFromGMT: 0)
        return (fmt.string(from: from), fmt.string(from: to))
    }
}

// MARK: - Menu Item

struct MenuItem: Identifiable {
    let id: String
    let name: String
    let action: () -> Void
}

// MARK: - View Model

@MainActor
class DashboardViewModel: ObservableObject {
    var deviceToken: String = ""

    @Published var selectedPeriod: DashboardPeriod = .today
    @Published var isCustomPeriod = false
    @Published var customFrom: String = ""
    @Published var customTo: String = ""
    @Published var selectedProductId: String?
    @Published var selectedAccountId: String?
    @Published var products: [FilterItem] = []
    @Published var accounts: [FilterItem] = []
    @Published var summary: DashboardSummary?
    @Published var isLoading = false
    @Published var lastUpdated: String?

    var statusText: String {
        if isLoading { return "carregando..." }
        if isCustomPeriod {
            // Custom period: "exibindo dados de hoje até HH:MM" or "exibindo dados de DD/MM HH:MM até DD/MM HH:MM"
            let brt = TimeZone(secondsFromGMT: -3 * 3600)!
            let iso = ISO8601DateFormatter(); iso.timeZone = TimeZone(secondsFromGMT: 0)
            guard let fromD = iso.date(from: customFrom), let toD = iso.date(from: customTo) else { return "" }
            var cal = Calendar.current; cal.timeZone = brt
            let now = Date()
            let fromIsToday = cal.isDate(fromD, inSameDayAs: now)
            let toIsToday = cal.isDate(toD, inSameDayAs: now)
            let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"; timeFmt.timeZone = brt
            let dateFmt = DateFormatter(); dateFmt.dateFormat = "dd/MM HH:mm"; dateFmt.timeZone = brt
            if fromIsToday && toIsToday {
                return "exibindo dados de hoje até \(timeFmt.string(from: toD))"
            } else {
                return "exibindo dados de \(dateFmt.string(from: fromD)) até \(dateFmt.string(from: toD))"
            }
        }
        if let ts = lastUpdated { return "atualizado às \(ts)" }
        return ""
    }

    private var autoRefreshTimer: Timer?
    private var backgroundedAt: Date?
    private var cancellables = Set<AnyCancellable>()

    var periodIncludesToday: Bool {
        if isCustomPeriod { return false }
        return [.today, .week, .month, .all].contains(selectedPeriod)
    }

    var periodDisplayLabel: String {
        if isCustomPeriod {
            let fmt = DateFormatter(); fmt.dateFormat = "dd/MM"
            fmt.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
            let iso = ISO8601DateFormatter(); iso.timeZone = TimeZone(secondsFromGMT: 0)
            if let f = iso.date(from: customFrom), let t = iso.date(from: customTo) {
                return "\(fmt.string(from: f)) — \(fmt.string(from: t))"
            }
            return "Personalizado"
        }
        return selectedPeriod.label
    }

    var selectedAccountName: String {
        if let id = selectedAccountId, let a = accounts.first(where: { $0.id == id }) { return a.name }
        return "Todas as CAs"
    }
    var selectedProductName: String {
        if let id = selectedProductId, let p = products.first(where: { $0.id == id }) { return p.name }
        return "Todos"
    }
    var accountMenuItems: [MenuItem] {
        var r = [MenuItem(id: "all", name: "Todas as CAs") { [weak self] in self?.selectedAccountId = nil }]
        r += accounts.map { a in MenuItem(id: a.id, name: a.name) { [weak self] in self?.selectedAccountId = a.id } }
        return r
    }
    var productMenuItems: [MenuItem] {
        var r = [MenuItem(id: "all", name: "Todos") { [weak self] in self?.selectedProductId = nil }]
        r += products.map { p in MenuItem(id: p.id, name: p.name) { [weak self] in self?.selectedProductId = p.id } }
        return r
    }

    func setupAutoRefresh() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.backgroundedAt = Date(); self?.stopAutoRefresh() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let away = self.backgroundedAt.map { Date().timeIntervalSince($0) } ?? 0
                self.backgroundedAt = nil
                if away >= 60 { Task { await self.loadSummary() } }
                if self.periodIncludesToday { self.startAutoRefresh() }
            }
            .store(in: &cancellables)
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self, !self.isLoading else { return }
            Task { @MainActor in await self.loadSummary() }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTimer?.invalidate(); autoRefreshTimer = nil
    }

    private let baseURL = DeviceManager.shared.baseURL

    func loadFilters() async {
        async let p: () = loadProducts()
        async let a: () = loadAccounts()
        _ = await (p, a)
    }
    private func loadProducts() async {
        guard let url = URL(string: "\(baseURL)/dashboard/products") else { return }
        var req = URLRequest(url: url); req.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let items = try? JSONDecoder().decode([FilterItem].self, from: data) else { return }
        products = items
    }
    private func loadAccounts() async {
        guard let url = URL(string: "\(baseURL)/dashboard/accounts") else { return }
        var req = URLRequest(url: url); req.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let items = try? JSONDecoder().decode([FilterItem].self, from: data) else { return }
        accounts = items
    }

    func loadSummary() async {
        isLoading = true
        let from: String; let to: String
        if isCustomPeriod { from = customFrom; to = customTo }
        else { let r = selectedPeriod.dateRange; from = r.from; to = r.to }

        var urlString = "\(baseURL)/dashboard/summary?from=\(from)&to=\(to)"
        if let pid = selectedProductId { urlString += "&productIds=\(pid)" }
        if let aid = selectedAccountId { urlString += "&adAccountIds=\(aid)" }

        guard let url = URL(string: urlString) else { isLoading = false; return }
        var req = URLRequest(url: url); req.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200 else { isLoading = false; return }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            summary = DashboardSummary(json: json)
            // Timestamp: only update for non-custom periods (matching desktop)
            if !isCustomPeriod {
                let fmt = DateFormatter(); fmt.dateFormat = "HH:mm:ss"
                fmt.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
                lastUpdated = fmt.string(from: Date())
            } else {
                lastUpdated = nil
            }
        }
        isLoading = false
    }
}

// MARK: - Data Models

struct FilterItem: Codable, Identifiable {
    let id: String
    let name: String
}

struct DashboardSummary {
    let spend, grossRevenue, netRevenue, profit: Int
    let roas, roi, margin: Double
    let pendingOrders, pendingRevenue, approvedOrders: Int
    let refundedOrders, refundedRevenue, chargedbackOrders, chargedbackRevenue, returnedRevenue: Int
    let totalOrders: Int
    let refundRate, chargebackRate: Double
    let arpu, cpa: Int
    let leads: Int
    let costPerLead: Int
    let salesTax, totalTax, metaAdsTax, fees: Int
    let productCosts, additionalExpenses: Int
    let conversations: Int
    let costPerConversation: Int

    init(json: [String: Any]) {
        spend = json["spend"] as? Int ?? 0
        grossRevenue = json["grossRevenue"] as? Int ?? 0
        netRevenue = json["netRevenue"] as? Int ?? 0
        profit = json["profit"] as? Int ?? 0
        roas = json["roas"] as? Double ?? 0
        roi = json["roi"] as? Double ?? 0
        margin = json["margin"] as? Double ?? 0
        pendingOrders = json["pendingOrders"] as? Int ?? 0
        pendingRevenue = json["pendingRevenue"] as? Int ?? 0
        approvedOrders = json["approvedOrders"] as? Int ?? 0
        refundedOrders = json["refundedOrders"] as? Int ?? 0
        refundedRevenue = json["refundedRevenue"] as? Int ?? 0
        chargedbackOrders = json["chargedbackOrders"] as? Int ?? 0
        chargedbackRevenue = json["chargedbackRevenue"] as? Int ?? 0
        returnedRevenue = json["returnedRevenue"] as? Int ?? 0
        totalOrders = json["totalOrders"] as? Int ?? 0
        refundRate = json["refundRate"] as? Double ?? 0
        chargebackRate = json["chargebackRate"] as? Double ?? 0
        arpu = json["arpu"] as? Int ?? 0
        cpa = json["cpa"] as? Int ?? 0
        leads = json["leads"] as? Int ?? 0
        costPerLead = json["costPerLead"] as? Int ?? 0
        salesTax = json["salesTax"] as? Int ?? 0
        totalTax = json["totalTax"] as? Int ?? 0
        metaAdsTax = json["metaAdsTax"] as? Int ?? 0
        fees = json["fees"] as? Int ?? 0
        productCosts = json["productCosts"] as? Int ?? 0
        additionalExpenses = json["additionalExpenses"] as? Int ?? 0
        conversations = json["conversations"] as? Int ?? 0
        costPerConversation = json["costPerConversation"] as? Int ?? 0
    }

    private func fmtCurrency(_ cents: Int) -> String {
        let v = Double(cents) / 100.0
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "BRL"
        f.locale = Locale(identifier: "pt_BR"); f.minimumFractionDigits = 2; f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "R$ 0,00"
    }
    private func fmtInt(_ v: Int) -> String { v == 0 ? "0" : String(v) }

    var spendFormatted: String { fmtCurrency(spend) }
    var grossRevenueFormatted: String { fmtCurrency(grossRevenue) }
    var netRevenueFormatted: String { fmtCurrency(netRevenue) }
    var profitFormatted: String { fmtCurrency(profit) }
    var pendingRevenueFormatted: String { fmtCurrency(pendingRevenue) }
    var refundedRevenueFormatted: String { fmtCurrency(refundedRevenue) }
    var chargedbackRevenueFormatted: String { fmtCurrency(chargedbackRevenue) }
    var returnedRevenueFormatted: String { fmtCurrency(returnedRevenue) }
    var arpuFormatted: String { fmtCurrency(arpu) }
    var cpaFormatted: String { fmtCurrency(cpa) }
    var leadsFormatted: String { fmtInt(leads) }
    var costPerLeadFormatted: String { fmtCurrency(costPerLead) }
    var salesTaxFormatted: String { fmtCurrency(salesTax) }
    var totalTaxFormatted: String { fmtCurrency(totalTax) }
    var metaAdsTaxFormatted: String { fmtCurrency(metaAdsTax) }
    var feesFormatted: String { fmtCurrency(fees) }
    var productCostsFormatted: String { fmtCurrency(productCosts) }
    var additionalExpensesFormatted: String { fmtCurrency(additionalExpenses) }
    var conversationsFormatted: String { fmtInt(conversations) }
    var costPerConversationFormatted: String { fmtCurrency(costPerConversation) }

    var roasFormatted: String { String(format: "%.2f", roas) }
    var roiFormatted: String { String(format: "%.2f", roi) }
    var marginFormatted: String { String(format: "%.1f%%", margin * 100) }
    var refundRateFormatted: String { String(format: "%.1f%%", refundRate * 100) }
    var chargebackRateFormatted: String { String(format: "%.1f%%", chargebackRate * 100) }

    var profitColor: Color { profit > 0 ? .mgGreen : profit < 0 ? .mgRed : .mgText }
    var roasColor: Color { roas >= 1 ? .mgGreen : roas > 0 ? .mgRed : .mgText }
    var roiColor: Color { roi >= 1 ? .mgGreen : roi > 0 ? .mgRed : .mgText }
    var marginColor: Color { margin > 0 ? .mgGreen : margin < 0 ? .mgRed : .mgText }
}
