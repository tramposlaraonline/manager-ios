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
            // Toolbar (same as Dashboard)
            toolbarSection
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)

            // Status filters
            statusFilters
                .padding(.bottom, 8)

            // Feed
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
        .background(Color.mgBg)
        .onAppear {
            if dm.isPaired && !dm.deviceToken.isEmpty && vm.orders.isEmpty {
                vm.deviceToken = dm.deviceToken
                Task {
                    await vm.loadFilters()
                    await vm.loadOrders()
                }
            }
        }
        .onReceive(dm.$deviceToken) { token in
            if dm.isPaired && !token.isEmpty && vm.orders.isEmpty {
                vm.deviceToken = token
                Task {
                    await vm.loadFilters()
                    await vm.loadOrders()
                }
            }
        }
        .sheet(isPresented: $showCustomDate) {
            ActivityDateSheet(vm: vm, isPresented: $showCustomDate)
        }
        .sheet(item: $selectedOrder) { order in
            OrderDetailSheet(order: order)
        }
    }

    // MARK: - Toolbar (matching Dashboard)

    private var toolbarSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    ForEach([DashboardPeriod.today, .yesterday, .week, .lastweek], id: \.self) { p in
                        actPeriodBtn(p.label, active: vm.selectedPeriod == p && !vm.isCustomPeriod) {
                            vm.selectedPeriod = p; vm.isCustomPeriod = false
                            Task { await vm.loadOrders() }
                        }
                    }
                }
                HStack(spacing: 1) {
                    ForEach([DashboardPeriod.month, .lastmonth, .all], id: \.self) { p in
                        actPeriodBtn(p.label, active: vm.selectedPeriod == p && !vm.isCustomPeriod) {
                            vm.selectedPeriod = p; vm.isCustomPeriod = false
                            Task { await vm.loadOrders() }
                        }
                    }
                    actPeriodBtn(vm.isCustomPeriod ? vm.periodDisplayLabel : "Período...",
                                 active: vm.isCustomPeriod) {
                        showCustomDate = true
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mgBorder, lineWidth: 1))
            .padding(.bottom, 12)

            Rectangle().fill(Color.mgBorder).frame(height: 1)

            HStack(spacing: 0) {
                filterChip(label: "Conta de Anúncio", value: vm.selectedAccountName, items: vm.accountMenuItems)
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

    private func actPeriodBtn(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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

    private func filterChip(label: String, value: String, items: [MenuItem]) -> some View {
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

    // MARK: - Status Filters

    private var statusFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                statusTab("Todas", filter: "all", icon: "list.bullet", count: nil)
                statusTab("Aprovadas", filter: "APPROVED", icon: "checkmark.circle", count: vm.statusCounts["APPROVED"], color: .mgGreen)
                statusTab("Pendentes", filter: "PENDING", icon: "clock", count: vm.statusCounts["PENDING"], color: .mgAmber)
                statusTab("Recusadas", filter: "REFUSED", icon: "xmark.circle", count: vm.statusCounts["REFUSED"], color: .mgRed)
                statusTab("Reembolsadas", filter: "REFUNDED", icon: "arrow.uturn.left.circle", count: vm.statusCounts["REFUNDED"], color: .mgRed)
                statusTab("Chargeback", filter: "CHARGEDBACK", icon: "exclamationmark.triangle", count: vm.statusCounts["CHARGEDBACK"], color: .mgRed)
            }
            .padding(.horizontal, 16)
        }
    }

    private func statusTab(_ label: String, filter: String, icon: String, count: Int?, color: Color = .mgText2) -> some View {
        Button(action: {
            vm.selectedFilter = filter
            Task { await vm.loadOrders() }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                }
                if let c = count, c > 0 {
                    Text("\(c)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(vm.selectedFilter == filter ? Color.mgAccent : Color.mgCard)
            .foregroundColor(vm.selectedFilter == filter ? .white : .mgText3)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(vm.selectedFilter == filter ? Color.clear : Color.mgBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Order Card

struct OrderCard: View {
    let order: ActivityOrder

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Status icon (SF Symbol)
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
                Section {
                    detailRow("Status", value: order.statusLabel, color: order.statusColor)
                    detailRow("Valor bruto", value: order.valueFormatted)
                    if order.netAmountCents > 0 {
                        detailRow("Valor líquido", value: order.netValueFormatted)
                    }
                } header: { Text("Venda") }

                Section {
                    detailRow("Produto", value: order.productName.isEmpty ? "—" : order.productName)
                    detailRow("Pagamento", value: order.paymentMethod.isEmpty ? "—" : order.paymentMethod.uppercased())
                } header: { Text("Detalhes") }

                Section {
                    detailRow("Cliente", value: order.customerName.isEmpty ? "—" : order.customerName)
                    detailRow("Email", value: order.customerEmail.isEmpty ? "—" : order.customerEmail)
                } header: { Text("Cliente") }

                Section {
                    detailRow("Campanha", value: order.utmCampaign.isEmpty ? "—" : order.utmCampaign)
                    detailRow("Fonte", value: order.utmSource.isEmpty ? "—" : order.utmSource)
                    detailRow("Origem", value: order.src.isEmpty ? "—" : order.src)
                } header: { Text("Atribuição") }

                Section {
                    detailRow("Criado em", value: order.fullDateFormatted)
                    if let approved = order.approvedDateFormatted {
                        detailRow("Aprovado em", value: approved)
                    }
                    detailRow("ID externo", value: order.externalOrderId.isEmpty ? "—" : order.externalOrderId)
                } header: { Text("Informações") }
            }
            .navigationTitle("Detalhes da Venda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color)
                .multilineTextAlignment(.trailing)
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

    @Published var selectedProductId: String?
    @Published var selectedAccountId: String?
    @Published var products: [FilterItem] = []
    @Published var accounts: [FilterItem] = []

    @Published var orders: [ActivityOrder] = []
    @Published var statusCounts: [String: Int] = [:]
    @Published var selectedFilter: String = "all"
    @Published var isLoading = false

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

    private let baseURL = DeviceManager.shared.baseURL

    func loadFilters() async {
        guard let url1 = URL(string: "\(baseURL)/dashboard/products"),
              let url2 = URL(string: "\(baseURL)/dashboard/accounts") else { return }
        var r1 = URLRequest(url: url1); r1.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        var r2 = URLRequest(url: url2); r2.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
        if let (d1, _) = try? await URLSession.shared.data(for: r1),
           let items = try? JSONDecoder().decode([FilterItem].self, from: d1) { products = items }
        if let (d2, _) = try? await URLSession.shared.data(for: r2),
           let items = try? JSONDecoder().decode([FilterItem].self, from: d2) { accounts = items }
    }

    func loadOrders() async {
        isLoading = true

        let from: String; let to: String
        if isCustomPeriod { from = customFrom; to = customTo }
        else { let r = selectedPeriod.dateRange; from = r.from; to = r.to }

        var urlString = "\(baseURL)/dashboard/orders?limit=50&from=\(from)&to=\(to)"
        if selectedFilter != "all" { urlString += "&status=\(selectedFilter)" }
        if let pid = selectedProductId { urlString += "&productIds=\(pid)" }

        guard let url = URL(string: urlString) else { isLoading = false; return }
        var req = URLRequest(url: url)
        req.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            isLoading = false; return
        }

        if let ordersJson = json["orders"] as? [[String: Any]] {
            orders = ordersJson.compactMap { ActivityOrder(json: $0) }
        }
        if let counts = json["statusCounts"] as? [String: Int] {
            statusCounts = counts
        }
        isLoading = false
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
                Section {
                    DatePicker("De", selection: $fromDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, brt)
                    DatePicker("Até", selection: $toDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, brt)
                        .onChange(of: toDate) { newVal in
                            var calBRT = Calendar.current; calBRT.timeZone = brt
                            let newDay = calBRT.ordinality(of: .day, in: .era, for: newVal) ?? 0
                            guard newDay != lastToDay else { return }
                            lastToDay = newDay
                            if calBRT.isDateInToday(newVal) {
                                let now = Date()
                                var comps = calBRT.dateComponents([.year, .month, .day], from: newVal)
                                comps.hour = calBRT.component(.hour, from: now)
                                comps.minute = calBRT.component(.minute, from: now); comps.second = 0
                                if let adj = calBRT.date(from: comps) { toDate = adj }
                            } else {
                                var comps = calBRT.dateComponents([.year, .month, .day], from: newVal)
                                comps.hour = 23; comps.minute = 59; comps.second = 59
                                if let adj = calBRT.date(from: comps) { toDate = adj }
                            }
                        }
                } header: { Text("Período personalizado") }
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
                        if fromDate >= toDate { validationError = "A data final deve ser posterior à data inicial."; return }
                        let fmt = ISO8601DateFormatter(); fmt.timeZone = TimeZone(secondsFromGMT: 0)
                        vm.customFrom = fmt.string(from: fromDate)
                        vm.customTo = fmt.string(from: toDate)
                        vm.isCustomPeriod = true
                        isPresented = false
                        Task { await vm.loadOrders() }
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            var calBRT = Calendar.current; calBRT.timeZone = brt
            fromDate = calBRT.startOfDay(for: Date()); toDate = Date()
            lastToDay = calBRT.ordinality(of: .day, in: .era, for: toDate) ?? 0
        }
    }
}

// MARK: - Models

struct OrderGroup: Identifiable {
    let date: String
    let label: String
    let orders: [ActivityOrder]
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
        guard let id = json["id"] as? String,
              let status = json["status"] as? String else { return nil }
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

        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let s = json["orderCreatedAt"] as? String { self.date = isoFmt.date(from: s) ?? Date() }
        else { self.date = Date() }
        if let s = json["approvedAt"] as? String { self.approvedAt = isoFmt.date(from: s) }
        else { self.approvedAt = nil }
    }

    var statusLabel: String {
        switch status {
        case "APPROVED": return "Venda aprovada"
        case "PENDING": return "Venda pendente"
        case "REFUSED": return "Venda recusada"
        case "REFUNDED": return "Venda reembolsada"
        case "CHARGEDBACK": return "Chargeback"
        default: return "Venda \(status.lowercased())"
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
        case "REFUSED", "REFUNDED", "CHARGEDBACK": return .mgRed
        default: return .mgText2
        }
    }

    private func fmtCurrency(_ cents: Int) -> String {
        let v = Double(cents) / 100.0
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "BRL"
        f.locale = Locale(identifier: "pt_BR"); f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "R$ 0,00"
    }

    var valueFormatted: String { fmtCurrency(grossAmountCents) }
    var netValueFormatted: String { fmtCurrency(netAmountCents) }

    var timeFormatted: String {
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
        return fmt.string(from: date)
    }

    var fullDateFormatted: String {
        let fmt = DateFormatter(); fmt.dateFormat = "dd/MM/yyyy HH:mm"
        fmt.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
        return fmt.string(from: date)
    }

    var approvedDateFormatted: String? {
        guard let d = approvedAt else { return nil }
        let fmt = DateFormatter(); fmt.dateFormat = "dd/MM/yyyy HH:mm"
        fmt.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
        return fmt.string(from: d)
    }

    var detail: String {
        var parts: [String] = []
        if !productName.isEmpty { parts.append(productName) }
        if !paymentMethod.isEmpty { parts.append(paymentMethod.uppercased()) }
        if !utmCampaign.isEmpty { parts.append(utmCampaign) }
        return parts.joined(separator: " • ")
    }
}
