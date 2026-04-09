import SwiftUI
import Combine
import UIKit

// MARK: - Activity View (Notifications Tab)

struct ActivityView: View {
    @StateObject private var vm = ActivityViewModel()
    @StateObject private var dm = DeviceManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Atividade")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.mgText)
                Spacer()
                if !vm.orders.isEmpty {
                    Text("\(vm.totalCount) vendas")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.mgText3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    filterPill("Todas", filter: "all", count: nil)
                    filterPill("Aprovadas", filter: "APPROVED", count: vm.statusCounts["APPROVED"], color: .mgGreen)
                    filterPill("Pendentes", filter: "PENDING", count: vm.statusCounts["PENDING"], color: .mgAmber)
                    filterPill("Recusadas", filter: "REFUSED", count: vm.statusCounts["REFUSED"], color: .mgRed)
                    filterPill("Reembolsadas", filter: "REFUNDED", count: vm.statusCounts["REFUNDED"], color: .mgRed)
                    filterPill("Chargeback", filter: "CHARGEDBACK", count: vm.statusCounts["CHARGEDBACK"], color: .mgRed)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)

            // Feed
            List {
                ForEach(vm.groupedOrders, id: \.date) { group in
                    Section {
                        ForEach(group.orders, id: \.id) { order in
                            OrderCard(order: order)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text(group.label)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.mgText3)
                            .textCase(.uppercase)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
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
                Task { await vm.loadOrders() }
            }
        }
        .onReceive(dm.$deviceToken) { token in
            if dm.isPaired && !token.isEmpty && vm.orders.isEmpty {
                vm.deviceToken = token
                Task { await vm.loadOrders() }
            }
        }
    }

    private func filterPill(_ label: String, filter: String, count: Int?, color: Color = .mgText2) -> some View {
        Button(action: {
            vm.selectedFilter = filter
            Task { await vm.loadOrders() }
        }) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                if let c = count, c > 0 {
                    Text("\(c)")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(vm.selectedFilter == filter ? Color.white.opacity(0.2) : color.opacity(0.15))
                        .foregroundColor(vm.selectedFilter == filter ? .white : color)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(vm.selectedFilter == filter ? Color.mgAccent : Color.white.opacity(0.04))
            .foregroundColor(vm.selectedFilter == filter ? .white : .mgText2)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(vm.selectedFilter == filter ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - Order Card

struct OrderCard: View {
    let order: ActivityOrder

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Status icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(order.statusColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Text(order.statusIcon)
                    .font(.system(size: 13))
            }
            .padding(.top, 2)

            // Info
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

// MARK: - View Model

@MainActor
class ActivityViewModel: ObservableObject {
    var deviceToken: String = ""

    @Published var orders: [ActivityOrder] = []
    @Published var statusCounts: [String: Int] = [:]
    @Published var selectedFilter: String = "all"
    @Published var isLoading = false

    var totalCount: Int { orders.count }

    var groupedOrders: [OrderGroup] {
        let brt = TimeZone(secondsFromGMT: -3 * 3600)!
        var cal = Calendar.current; cal.timeZone = brt
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!

        var groups: [String: (label: String, orders: [ActivityOrder], sortKey: Date)] = [:]

        for order in orders {
            let key: String
            let label: String
            if order.date >= todayStart {
                key = "today"; label = "Hoje"
            } else if order.date >= yesterdayStart {
                key = "yesterday"; label = "Ontem"
            } else {
                let fmt = DateFormatter(); fmt.dateFormat = "dd/MM/yyyy"; fmt.timeZone = brt
                key = fmt.string(from: order.date); label = key
            }
            if groups[key] == nil { groups[key] = (label: label, orders: [], sortKey: order.date) }
            groups[key]!.orders.append(order)
        }

        return groups.values
            .sorted { $0.sortKey > $1.sortKey }
            .map { OrderGroup(date: $0.label, label: $0.label, orders: $0.orders) }
    }

    private let baseURL = DeviceManager.shared.baseURL

    func loadOrders() async {
        isLoading = true
        var urlString = "\(baseURL)/dashboard/orders?limit=50"
        if selectedFilter != "all" { urlString += "&status=\(selectedFilter)" }

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

// MARK: - Models

struct OrderGroup: Identifiable {
    let date: String
    let label: String
    let orders: [ActivityOrder]
    var id: String { date }
}

struct ActivityOrder: Identifiable {
    let id: String
    let status: String
    let grossAmountCents: Int
    let paymentMethod: String
    let productName: String
    let utmCampaign: String
    let date: Date

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String,
              let status = json["status"] as? String else { return nil }
        self.id = id
        self.status = status
        self.grossAmountCents = json["grossAmountCents"] as? Int ?? 0
        self.paymentMethod = json["paymentMethod"] as? String ?? ""
        self.productName = json["productName"] as? String ?? ""
        self.utmCampaign = json["utmCampaign"] as? String ?? ""
        if let dateStr = json["orderCreatedAt"] as? String {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.date = fmt.date(from: dateStr) ?? Date()
        } else {
            self.date = Date()
        }
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
        case "APPROVED": return "✓"
        case "PENDING": return "⏳"
        case "REFUSED": return "✗"
        case "REFUNDED": return "↩"
        case "CHARGEDBACK": return "⚠"
        default: return "•"
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

    var valueFormatted: String {
        let v = Double(grossAmountCents) / 100.0
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "BRL"
        f.locale = Locale(identifier: "pt_BR"); f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "R$ 0,00"
    }

    var timeFormatted: String {
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(secondsFromGMT: -3 * 3600)
        return fmt.string(from: date)
    }

    var detail: String {
        var parts: [String] = []
        if !productName.isEmpty { parts.append(productName) }
        if !paymentMethod.isEmpty { parts.append(paymentMethod.uppercased()) }
        if !utmCampaign.isEmpty { parts.append(utmCampaign) }
        return parts.joined(separator: " • ")
    }
}
