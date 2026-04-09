import SwiftUI

struct ContentView: View {
    @StateObject private var dm = DeviceManager.shared

    var body: some View {
        if dm.isPaired {
            MainTabView()
        } else {
            PairingView()
        }
    }
}

// MARK: - Tab Bar

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill").environment(\.symbolVariants, .fill)
                }
                .tag(0)

            NotificationsPlaceholderView()
                .tabItem {
                    Image(systemName: "bell").environment(\.symbolVariants, .none)
                }
                .tag(1)

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gearshape").environment(\.symbolVariants, .none)
            }
            .tag(2)
        }
        .accentColor(.mgAccent)
        .preferredColorScheme(.dark)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.backgroundColor = UIColor(Color.mgCard)
            appearance.shadowColor = UIColor(Color.mgBorder)
            // Smaller icons
            let itemAppearance = UITabBarItemAppearance()
            itemAppearance.normal.iconColor = UIColor(Color.mgText3)
            itemAppearance.selected.iconColor = UIColor(Color.mgAccent)
            appearance.stackedLayoutAppearance = itemAppearance
            appearance.inlineLayoutAppearance = itemAppearance
            appearance.compactInlineLayoutAppearance = itemAppearance
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Notifications Placeholder

struct NotificationsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundColor(.mgText3)
            Text("Notificações")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.mgText)
            Text("Histórico de notificações em breve")
                .font(.system(size: 13))
                .foregroundColor(.mgText3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.mgBg)
    }
}

// MARK: - Pairing View

struct PairingView: View {
    @StateObject private var dm = DeviceManager.shared
    @State private var code: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.mgAccent)

            Text("Manager")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.mgText)

            Text("Digite o código de pareamento\ngerado no painel web")
                .multilineTextAlignment(.center)
                .foregroundColor(.mgText3)

            TextField("000000", text: $code)
                .keyboardType(.numberPad)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(.mgText)
                .padding()
                .background(Color.mgCard)
                .cornerRadius(9)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.mgBorder, lineWidth: 1)
                )
                .padding(.horizontal, 60)

            if !dm.pairingError.isEmpty {
                Text(dm.pairingError)
                    .foregroundColor(.mgRed)
                    .font(.caption)
            }

            Button(action: {
                Task { await dm.pairWithCode(code) }
            }) {
                if dm.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Conectar")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(Color.mgAccent)
            .foregroundColor(.white)
            .cornerRadius(9)
            .padding(.horizontal, 40)
            .disabled(code.count != 6 || dm.isLoading)
            .opacity(code.count == 6 ? 1 : 0.5)

            Spacer()
            Spacer()
        }
        .background(Color.mgBg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var dm = DeviceManager.shared

    var body: some View {
        List {
            Section {
                Toggle("Vendas pendentes", isOn: $dm.notifyPending)
                    .onChange(of: dm.notifyPending) { val in
                        Task { await dm.updatePreference("notifyPending", value: val) }
                    }
                Toggle("Vendas aprovadas", isOn: $dm.notifyApproved)
                    .onChange(of: dm.notifyApproved) { val in
                        Task { await dm.updatePreference("notifyApproved", value: val) }
                    }
                Toggle("Vendas recusadas", isOn: $dm.notifyRefused)
                    .onChange(of: dm.notifyRefused) { val in
                        Task { await dm.updatePreference("notifyRefused", value: val) }
                    }
                Toggle("Vendas reembolsadas", isOn: $dm.notifyRefunded)
                    .onChange(of: dm.notifyRefunded) { val in
                        Task { await dm.updatePreference("notifyRefunded", value: val) }
                    }
            } header: {
                Text("Notificações de Venda")
            }

            Section {
                Picker("Valor da venda", selection: $dm.valueDisplay) {
                    Text("Líquido").tag("net")
                    Text("Bruto").tag("gross")
                    Text("Esconder").tag("hidden")
                }
                .onChange(of: dm.valueDisplay) { val in
                    Task { await dm.updatePreference("valueDisplay", value: val) }
                }
                Toggle("Nome do produto", isOn: $dm.showProductName)
                    .onChange(of: dm.showProductName) { val in
                        Task { await dm.updatePreference("showProductName", value: val) }
                    }
                Toggle("Valor de utm_campaign", isOn: $dm.showCampaignName)
                    .onChange(of: dm.showCampaignName) { val in
                        Task { await dm.updatePreference("showCampaignName", value: val) }
                    }
            } header: {
                Text("Formato da Notificação")
            }

            Section {
                NotificationPreview(dm: dm)
            } header: {
                Text("Prévia")
            }

            Section {
                Toggle("08:00", isOn: $dm.reportAt08)
                    .onChange(of: dm.reportAt08) { val in
                        Task { await dm.updatePreference("reportAt08", value: val) }
                    }
                Toggle("12:00", isOn: $dm.reportAt12)
                    .onChange(of: dm.reportAt12) { val in
                        Task { await dm.updatePreference("reportAt12", value: val) }
                    }
                Toggle("18:00", isOn: $dm.reportAt18)
                    .onChange(of: dm.reportAt18) { val in
                        Task { await dm.updatePreference("reportAt18", value: val) }
                    }
                Toggle("23:00", isOn: $dm.reportAt23)
                    .onChange(of: dm.reportAt23) { val in
                        Task { await dm.updatePreference("reportAt23", value: val) }
                    }
            } header: {
                Text("Relatórios Agendados")
            }

            Section {
                Button(role: .destructive) {
                    dm.unpair()
                } label: {
                    HStack {
                        Spacer()
                        Text("Parear novamente")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Ajustes")
        .onAppear {
            Task { await dm.fetchPreferences() }
        }
    }
}

// MARK: - Notification Preview

struct NotificationPreview: View {
    @ObservedObject var dm: DeviceManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.title2)
                .foregroundColor(.mgAccent)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray5))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text("Venda aprovada!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(previewBody)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    var previewBody: String {
        var parts: [String] = []
        if dm.valueDisplay == "net" {
            parts.append("Valor líquido: R$ 16,77")
        } else if dm.valueDisplay == "gross" {
            parts.append("Valor bruto: R$ 17,81")
        }
        if dm.showProductName { parts.append("Taxa de validação") }
        if dm.showCampaignName { parts.append("SITE ABO - 2/3") }
        return parts.isEmpty ? "Notificação de venda" : parts.joined(separator: " | ")
    }
}
