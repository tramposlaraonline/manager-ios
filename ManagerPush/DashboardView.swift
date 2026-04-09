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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Toolbar: period + filters
                toolbarSection

                // Last updated
                if let ts = vm.lastUpdated {
                    HStack {
                        Spacer()
                        Text("atualizado às \(ts)")
                            .font(.system(size: 10))
                            .foregroundColor(.mgText3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                }

                // Metrics
                metricsSection
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            await vm.loadSummary()
        }
        .background(Color.mgBg)
        .onAppear {
            if dm.isPaired && !dm.deviceToken.isEmpty {
                vm.deviceToken = dm.deviceToken
                Task {
                    await vm.loadFilters()
                    await vm.loadSummary()
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
    }

    // MARK: - Toolbar

    private var toolbarSection: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(DashboardPeriod.allCases, id: \.self) { period in
                        Button(action: {
                            vm.selectedPeriod = period
                            Task { await vm.loadSummary() }
                        }) {
                            Text(period.label)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(vm.selectedPeriod == period ? Color.mgAccent : Color.white.opacity(0.04))
                                .foregroundColor(vm.selectedPeriod == period ? .white : .mgText2)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(vm.selectedPeriod == period ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.bottom, 10)

            Rectangle().fill(Color.mgBorder).frame(height: 1)

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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private func filterChip(label: String, value: String, items: [MenuItem]) -> some View {
        Menu {
            ForEach(items, id: \.id) { item in
                Button(item.name) {
                    item.action()
                    Task { await vm.loadSummary() }
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

    private var metricsSection: some View {
        VStack(spacing: 10) {
            if vm.isLoading && vm.summary == nil {
                // Skeleton loading
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonCard()
                }
                HStack(spacing: 10) {
                    SkeletonCard(); SkeletonCard(); SkeletonCard()
                }
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard()
                }
            } else if let s = vm.summary {
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

                // Reembolsadas 70% | Reembolso % 30%
                GeometryReader { geo in
                    HStack(spacing: 10) {
                        MetricCard(label: "Vendas Reembolsadas", value: s.refundedRevenueFormatted)
                            .frame(width: (geo.size.width - 10) * 0.7)
                        MetricCard(label: "Reembolso", value: s.refundRateFormatted)
                            .frame(width: (geo.size.width - 10) * 0.3)
                    }
                }
                .frame(height: 72)

                // Chargeback 70% | Chargeback % 30%
                GeometryReader { geo in
                    HStack(spacing: 10) {
                        MetricCard(label: "Vendas Chargeback", value: s.chargedbackRevenueFormatted)
                            .frame(width: (geo.size.width - 10) * 0.7)
                        MetricCard(label: "Chargeback", value: s.chargebackRateFormatted)
                            .frame(width: (geo.size.width - 10) * 0.3)
                    }
                }
                .frame(height: 72)

                MetricCard(label: "Vendas Devolvidas", value: s.returnedRevenueFormatted)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Skeleton Loading Card

struct SkeletonCard: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.mgBorder.opacity(0.5))
                .frame(width: 100, height: 10)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.mgBorder.opacity(0.4))
                .frame(width: 150, height: 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.mgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.mgBorder, lineWidth: 1)
                )
        )
        .opacity(shimmer ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: shimmer)
        .onAppear { shimmer = true }
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
                // Gradient clipped to full rounded rect so corners aren't sharp
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

// MARK: - Period Enum (matching desktop: Hoje, Ontem, Semana, Sem. passada, Mês, Mês passado, Tudo)

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
    @Published var selectedProductId: String?
    @Published var selectedAccountId: String?
    @Published var products: [FilterItem] = []
    @Published var accounts: [FilterItem] = []
    @Published var summary: DashboardSummary?
    @Published var isLoading = false
    @Published var lastUpdated: String?

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
        let range = selectedPeriod.dateRange
        var urlString = "\(baseURL)/dashboard/summary?from=\(range.from)&to=\(range.to)"
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
