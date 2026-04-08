import SwiftUI
import Combine
import UIKit

// MARK: - Color Constants (matching Manager design system)

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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                periodSelector
                filterRow
                metricsSection
            }
            .padding(.bottom, 20)
        }
        .background(Color.mgBg)
        .onAppear {
            if dm.isPaired {
                vm.deviceToken = dm.deviceToken
                Task {
                    await vm.loadFilters()
                    await vm.loadSummary()
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Dashboard")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.mgText)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DashboardPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        vm.selectedPeriod = period
                        Task { await vm.loadSummary() }
                    }) {
                        Text(period.label)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(vm.selectedPeriod == period ? Color.mgAccent : Color.mgCard)
                            .foregroundColor(vm.selectedPeriod == period ? .white : .mgText2)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(vm.selectedPeriod == period ? Color.clear : Color.mgBorder, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        HStack(spacing: 16) {
            Menu {
                Button("Todas as CAs") {
                    vm.selectedAccountId = nil
                    Task { await vm.loadSummary() }
                }
                ForEach(vm.accounts, id: \.id) { acc in
                    Button(acc.name) {
                        vm.selectedAccountId = acc.id
                        Task { await vm.loadSummary() }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.selectedAccountName)
                        .font(.system(size: 11))
                        .foregroundColor(.mgText3)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.mgText3)
                }
            }

            Menu {
                Button("Todos os Produtos") {
                    vm.selectedProductId = nil
                    Task { await vm.loadSummary() }
                }
                ForEach(vm.products, id: \.id) { prod in
                    Button(prod.name) {
                        vm.selectedProductId = prod.id
                        Task { await vm.loadSummary() }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.selectedProductName)
                        .font(.system(size: 11))
                        .foregroundColor(.mgText3)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.mgText3)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(spacing: 10) {
            if vm.isLoading && vm.summary == nil {
                ProgressView()
                    .tint(.mgAccent)
                    .padding(.top, 40)
            } else if let s = vm.summary {
                // Row 1: Gastos com Anúncios
                MetricCard(label: "Gastos com Anúncios", value: s.spendFormatted)

                // Row 2: Faturamento Bruto
                MetricCard(label: "Faturamento Bruto", value: s.grossRevenueFormatted)

                // Row 3: Faturamento Líquido
                MetricCard(label: "Faturamento Líquido", value: s.netRevenueFormatted)

                // Row 4: Lucro
                MetricCard(label: "Lucro", value: s.profitFormatted, valueColor: s.profitColor)

                // Row 5: ROAS | ROI | Margem
                HStack(spacing: 10) {
                    MetricCard(label: "ROAS", value: s.roasFormatted, valueColor: s.roasColor)
                    MetricCard(label: "ROI", value: s.roiFormatted, valueColor: s.roiColor)
                    MetricCard(label: "Margem", value: s.marginFormatted, valueColor: s.marginColor)
                }

                // Row 6: Vendas Pendentes
                MetricCard(label: "Vendas Pendentes", value: "\(s.pendingOrders)", valueColor: s.pendingOrders > 0 ? .mgAmber : .mgText)

                // Row 7: Reembolsadas (70%) | Reembolso (30%)
                HStack(spacing: 10) {
                    MetricCard(label: "Vendas Reembolsadas", value: "\(s.refundedOrders)", valueColor: s.refundedOrders > 0 ? .mgRed : .mgText)
                        .frame(maxWidth: .infinity)
                    MetricCard(label: "Reembolso", value: s.refundedRevenueFormatted, valueColor: s.refundedOrders > 0 ? .mgRed : .mgText)
                        .frame(maxWidth: .infinity)
                        .frame(width: UIScreen.main.bounds.width * 0.28)
                }

                // Row 8: Chargeback (70%) | Chargeback R$ (30%)
                HStack(spacing: 10) {
                    MetricCard(label: "Vendas Chargeback", value: "\(s.chargedbackOrders)", valueColor: s.chargedbackOrders > 0 ? .mgRed : .mgText)
                        .frame(maxWidth: .infinity)
                    MetricCard(label: "Chargeback", value: s.chargedbackRevenueFormatted, valueColor: s.chargedbackOrders > 0 ? .mgRed : .mgText)
                        .frame(maxWidth: .infinity)
                        .frame(width: UIScreen.main.bounds.width * 0.28)
                }

                // Row 9: Vendas Devolvidas
                MetricCard(label: "Vendas Devolvidas", value: "\(s.refundedOrders + s.chargedbackOrders)")
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let label: String
    let value: String
    var valueColor: Color = .mgText

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(.mgText2)
                .tracking(1)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
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
                // Purple gradient top bar
                LinearGradient(
                    gradient: Gradient(colors: [Color.mgAccent.opacity(0.6), Color.clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 2)
                .clipShape(
                    RoundedCorner(radius: 9, corners: [.topLeft, .topRight])
                )
            }
        )
    }
}

// Helper for top-only corner radius
struct RoundedCorner: Shape {
    var radius: CGFloat = 0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Period Enum

enum DashboardPeriod: CaseIterable {
    case today, yesterday, days7, days14, days30, month

    var label: String {
        switch self {
        case .today: return "Hoje"
        case .yesterday: return "Ontem"
        case .days7: return "7d"
        case .days14: return "14d"
        case .days30: return "30d"
        case .month: return "Mês"
        }
    }

    var dateRange: (from: String, to: String) {
        let cal = Calendar.current
        let now = Date()
        // BRT = UTC-3
        let brt = TimeZone(secondsFromGMT: -3 * 3600)!
        var calBRT = Calendar.current
        calBRT.timeZone = brt

        let todayStart = calBRT.startOfDay(for: now)

        let from: Date
        let to: Date

        switch self {
        case .today:
            from = todayStart
            to = now
        case .yesterday:
            from = calBRT.date(byAdding: .day, value: -1, to: todayStart)!
            to = todayStart.addingTimeInterval(-1)
        case .days7:
            from = calBRT.date(byAdding: .day, value: -6, to: todayStart)!
            to = now
        case .days14:
            from = calBRT.date(byAdding: .day, value: -13, to: todayStart)!
            to = now
        case .days30:
            from = calBRT.date(byAdding: .day, value: -29, to: todayStart)!
            to = now
        case .month:
            var comps = calBRT.dateComponents([.year, .month], from: now)
            comps.day = 1
            comps.hour = 0
            comps.minute = 0
            comps.second = 0
            from = calBRT.date(from: comps)!
            to = now
        }

        let fmt = ISO8601DateFormatter()
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        return (fmt.string(from: from), fmt.string(from: to))
    }
}

// MARK: - View Model

@MainActor
class DashboardViewModel: ObservableObject {
    var deviceToken: String = ""

    @Published var selectedPeriod: DashboardPeriod = .today
    @Published var selectedProductId: String?
    @Published var selectedAccountId: String?
    @Published var products: [FilterItem] = []
    @Published var accounts: [FilterItem] = []
    @Published var summary: DashboardSummary?
    @Published var isLoading = false

    var selectedAccountName: String {
        if let id = selectedAccountId, let acc = accounts.first(where: { $0.id == id }) {
            return acc.name
        }
        return "Todas as CAs"
    }

    var selectedProductName: String {
        if let id = selectedProductId, let prod = products.first(where: { $0.id == id }) {
            return prod.name
        }
        return "Todos os Produtos"
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
        let range = selectedPeriod.dateRange

        var urlString = "\(baseURL)/dashboard/summary?from=\(range.from)&to=\(range.to)"
        if let pid = selectedProductId { urlString += "&productIds=\(pid)" }
        if let aid = selectedAccountId { urlString += "&adAccountIds=\(aid)" }

        guard let url = URL(string: urlString) else { isLoading = false; return }
        var req = URLRequest(url: url)
        req.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            isLoading = false
            return
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            summary = DashboardSummary(json: json)
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
    let approvedOrders: Int
    let refundedOrders: Int
    let refundedRevenue: Int
    let chargedbackOrders: Int
    let chargedbackRevenue: Int
    let totalOrders: Int

    init(json: [String: Any]) {
        spend = json["spend"] as? Int ?? 0
        grossRevenue = json["grossRevenue"] as? Int ?? 0
        netRevenue = json["netRevenue"] as? Int ?? 0
        profit = json["profit"] as? Int ?? 0
        roas = json["roas"] as? Double ?? 0
        roi = json["roi"] as? Double ?? 0
        margin = json["margin"] as? Double ?? 0
        pendingOrders = json["pendingOrders"] as? Int ?? 0
        approvedOrders = json["approvedOrders"] as? Int ?? 0
        refundedOrders = json["refundedOrders"] as? Int ?? 0
        refundedRevenue = json["refundedRevenue"] as? Int ?? 0
        chargedbackOrders = json["chargedbackOrders"] as? Int ?? 0
        chargedbackRevenue = json["chargedbackRevenue"] as? Int ?? 0
        totalOrders = json["totalOrders"] as? Int ?? 0
    }

    // Formatters
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
    var refundedRevenueFormatted: String { fmtCurrency(refundedRevenue) }
    var chargedbackRevenueFormatted: String { fmtCurrency(chargedbackRevenue) }

    var roasFormatted: String { String(format: "%.2f", roas) }
    var roiFormatted: String { String(format: "%.2f", roi) }
    var marginFormatted: String { String(format: "%.1f%%", margin * 100) }

    var profitColor: Color { profit > 0 ? .mgGreen : profit < 0 ? .mgRed : .mgText }
    var roasColor: Color { roas >= 1 ? .mgGreen : roas > 0 ? .mgRed : .mgText }
    var roiColor: Color { roi >= 1 ? .mgGreen : roi > 0 ? .mgRed : .mgText }
    var marginColor: Color { margin > 0 ? .mgGreen : margin < 0 ? .mgRed : .mgText }
}
