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
        List {
            toolbarSection
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            metricsContent
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await vm.loadSummary()
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
            // Period pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(DashboardPeriod.allCases, id: \.self) { period in
                        periodPill(label: period.label, isActive: vm.selectedPeriod == period && !vm.isCustomPeriod) {
                            vm.selectedPeriod = period
                            vm.isCustomPeriod = false
                            Task { await vm.loadSummary() }
                            if vm.periodIncludesToday { vm.startAutoRefresh() } else { vm.stopAutoRefresh() }
                        }
                    }
                    // Custom period pill
                    periodPill(
                        label: vm.isCustomPeriod ? vm.periodDisplayLabel : "Período...",
                        isActive: vm.isCustomPeriod
                    ) {
                        showCustomDate = true
                    }
                }
            }
            .padding(.bottom, 10)

            // Updated timestamp
            if let ts = vm.lastUpdated {
                HStack {
                    Spacer()
                    Text("atualizado às \(ts)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.mgText3.opacity(0.5))
                }
                .padding(.bottom, 8)
            }

            Rectangle().fill(Color.mgBorder).frame(height: 1)

            // Filters
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
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.mgBorder, lineWidth: 1)
                )
        )
    }

    private func periodPill(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(isActive ? Color.mgAccent : Color.white.opacity(0.04))
                .foregroundColor(isActive ? .white : .mgText2)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
                )
        }
    }

    private func filterChip(label: String, value: String, items: [MenuItem]) -> some View {
        Menu {
            ForEach(items, id: \.id) { item in
                Button(action: {
                    item.action()
                    Task { await vm.loadSummary() }
                }) {
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
    @State private var lastToDay: Int = 0 // track day changes only
    @State private var validationError: String?

    private let brt = TimeZone(secondsFromGMT: -3 * 3600)!

    private var isToDateToday: Bool {
        var calBRT = Calendar.current
        calBRT.timeZone = brt
        return calBRT.isDateInToday(toDate)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("De", selection: $fromDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, brt)
                    DatePicker("Até", selection: $toDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, brt)
                        .onChange(of: toDate) { newVal in
                            // Only auto-set time when the DAY changes, not when user edits time
                            var calBRT = Calendar.current
                            calBRT.timeZone = brt
                            let newDay = calBRT.ordinality(of: .day, in: .era, for: newVal) ?? 0
                            guard newDay != lastToDay else { return }
                            lastToDay = newDay

                            if calBRT.isDateInToday(newVal) {
                                let now = Date()
                                let h = calBRT.component(.hour, from: now)
                                let m = calBRT.component(.minute, from: now)
                                var comps = calBRT.dateComponents([.year, .month, .day], from: newVal)
                                comps.hour = h; comps.minute = m; comps.second = 0
                                if let adjusted = calBRT.date(from: comps) { toDate = adjusted }
                            } else {
                                var comps = calBRT.dateComponents([.year, .month, .day], from: newVal)
                                comps.hour = 23; comps.minute = 59; comps.second = 59
                                if let adjusted = calBRT.date(from: comps) { toDate = adjusted }
                            }
                        }
                } header: {
                    Text("Período personalizado")
                }

                if let err = validationError {
                    Section {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.mgRed)
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
                        // Validation: from must be before to
                        if fromDate >= toDate {
                            validationError = "A data final deve ser posterior à data inicial."
                            return
                        }
                        validationError = nil
                        let fmt = ISO8601DateFormatter()
                        fmt.timeZone = TimeZone(secondsFromGMT: 0)
                        vm.customFrom = fmt.string(from: fromDate)
                        vm.customTo = fmt.string(from: toDate)
                        vm.isCustomPeriod = true
                        isPresented = false
                        Task { await vm.loadSummary() }
                        // Custom period including today → auto-refresh, else stop
                        if isToDateToday { vm.startAutoRefresh() } else { vm.stopAutoRefresh() }
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
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.mgCard)
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.mgBorder, lineWidth: 1)
                LinearGradient(
                    gradient: Gradient(colors: [Color.mgAccent.opacity(0.6), Color.clear]),
                    startPoint: .leading,
                    endPoint: .trailing
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

        let from: Date
        let to: Date

        switch self {
        case .today:
            from = todayStart
            to = Date(timeInterval: day - 1, since: todayStart)
        case .yesterday:
            from = Date(timeInterval: -day, since: todayStart)
            to = Date(timeInterval: -1, since: todayStart)
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
            from = calBRT.date(from: c)!
            to = Date(timeInterval: day - 1, since: todayStart)
        case .lastmonth:
            var c = calBRT.dateComponents([.year, .month], from: now)
            c.month! -= 1; c.day = 1; c.hour = 0; c.minute = 0; c.second = 0
            from = calBRT.date(from: c)!
            var e = calBRT.dateComponents([.year, .month], from: now)
            e.day = 1; e.hour = 0; e.minute = 0; e.second = 0
            to = Date(timeInterval: -1, since: calBRT.date(from: e)!)
        case .all:
            let fmt2 = ISO8601DateFormatter()
            fmt2.timeZone = TimeZone(secondsFromGMT: 0)
            from = fmt2.date(from: "2020-01-01T03:00:00Z")!
            to = Date(timeInterval: day - 1, since: todayStart)
        }

        let fmt = ISO8601DateFormatter()
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
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

    private var autoRefreshTimer: Timer?
    private var backgroundedAt: Date?
    private var cancellables = Set<AnyCancellable>()

    // Auto-refresh periods (those that include today)
    var periodIncludesToday: Bool {
        if isCustomPeriod { return true } // assume custom may include today
        return [.today, .week, .month, .all].contains(selectedPeriod)
    }

    func setupAutoRefresh() {
        // Observe app going to background/foreground
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.backgroundedAt = Date(); self?.stopAutoRefresh() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let away = self.backgroundedAt.map { Date().timeIntervalSince($0) } ?? 0
                self.backgroundedAt = nil
                if away >= 60 {
                    Task { await self.loadSummary() }
                }
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
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    var periodDisplayLabel: String {
        if isCustomPeriod {
            // Show short date range
            let fmt = DateFormatter()
            fmt.dateFormat = "dd/MM"
            fmt.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
            let isoFmt = ISO8601DateFormatter()
            isoFmt.timeZone = TimeZone(secondsFromGMT: 0)
            if let f = isoFmt.date(from: customFrom), let t = isoFmt.date(from: customTo) {
                return "\(fmt.string(from: f)) — \(fmt.string(from: t))"
            }
            return "Personalizado"
        }
        return selectedPeriod.label
    }

    var selectedAccountName: String {
        if let id = selectedAccountId, let acc = accounts.first(where: { $0.id == id }) { return acc.name }
        return "Todas as CAs"
    }

    var selectedProductName: String {
        if let id = selectedProductId, let prod = products.first(where: { $0.id == id }) { return prod.name }
        return "Todos"
    }

    var accountMenuItems: [MenuItem] {
        var items = [MenuItem(id: "all", name: "Todas as CAs") { [weak self] in self?.selectedAccountId = nil }]
        items += accounts.map { acc in MenuItem(id: acc.id, name: acc.name) { [weak self] in self?.selectedAccountId = acc.id } }
        return items
    }

    var productMenuItems: [MenuItem] {
        var items = [MenuItem(id: "all", name: "Todos") { [weak self] in self?.selectedProductId = nil }]
        items += products.map { prod in MenuItem(id: prod.id, name: prod.name) { [weak self] in self?.selectedProductId = prod.id } }
        return items
    }

    private let baseURL = DeviceManager.shared.baseURL

    func loadFilters() async {
        async let p: () = loadProducts()
        async let a: () = loadAccounts()
        _ = await (p, a)
    }

    private func loadProducts() async {
        guard let url = URL(string: "\(baseURL)/dashboard/products") else { return }
        var req = URLRequest(url: url)
        req.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let items = try? JSONDecoder().decode([FilterItem].self, from: data) else { return }
        products = items
    }

    private func loadAccounts() async {
        guard let url = URL(string: "\(baseURL)/dashboard/accounts") else { return }
        var req = URLRequest(url: url)
        req.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let items = try? JSONDecoder().decode([FilterItem].self, from: data) else { return }
        accounts = items
    }

    func loadSummary() async {
        isLoading = true

        let from: String
        let to: String
        if isCustomPeriod {
            from = customFrom
            to = customTo
        } else {
            let range = selectedPeriod.dateRange
            from = range.from
            to = range.to
        }

        var urlString = "\(baseURL)/dashboard/summary?from=\(from)&to=\(to)"
        if let pid = selectedProductId { urlString += "&productIds=\(pid)" }
        if let aid = selectedAccountId { urlString += "&adAccountIds=\(aid)" }

        guard let url = URL(string: urlString) else { isLoading = false; return }
        var req = URLRequest(url: url)
        req.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            isLoading = false; return
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            summary = DashboardSummary(json: json)
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm:ss"
            fmt.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
            lastUpdated = fmt.string(from: Date())
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
    let spend: Int
    let grossRevenue: Int
    let netRevenue: Int
    let profit: Int
    let roas: Double
    let roi: Double
    let margin: Double
    let pendingOrders: Int
    let pendingRevenue: Int
    let approvedOrders: Int
    let refundedOrders: Int
    let refundedRevenue: Int
    let chargedbackOrders: Int
    let chargedbackRevenue: Int
    let returnedRevenue: Int
    let totalOrders: Int
    let refundRate: Double
    let chargebackRate: Double

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
    }

    private func fmtCurrency(_ cents: Int) -> String {
        let value = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    var spendFormatted: String { fmtCurrency(spend) }
    var grossRevenueFormatted: String { fmtCurrency(grossRevenue) }
    var netRevenueFormatted: String { fmtCurrency(netRevenue) }
    var profitFormatted: String { fmtCurrency(profit) }
    var pendingRevenueFormatted: String { fmtCurrency(pendingRevenue) }
    var refundedRevenueFormatted: String { fmtCurrency(refundedRevenue) }
    var chargedbackRevenueFormatted: String { fmtCurrency(chargedbackRevenue) }
    var returnedRevenueFormatted: String { fmtCurrency(returnedRevenue) }

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
