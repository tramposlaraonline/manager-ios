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
                    Image(systemName: "chart.bar")
                }
                .tag(0)

            ActivityView()
                .tabItem {
                    Image(systemName: "bell")
                }
                .tag(1)

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gearshape")
            }
            .tag(2)
        }
        .accentColor(.mgAccent)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.mgCard)
            appearance.shadowColor = UIColor(Color.mgBorder)
            let item = UITabBarItemAppearance()
            item.normal.iconColor = UIColor(Color.mgText3)
            item.selected.iconColor = UIColor(Color.mgAccent)
            appearance.stackedLayoutAppearance = item
            appearance.inlineLayoutAppearance = item
            appearance.compactInlineLayoutAppearance = item
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
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
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var dm = DeviceManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Notifications section
                settingsCard {
                    settingsHeader("Notificações de Venda", icon: "bell.fill")
                    settingsToggle("Vendas pendentes", isOn: $dm.notifyPending, key: "notifyPending")
                    settingsToggle("Vendas aprovadas", isOn: $dm.notifyApproved, key: "notifyApproved")
                    settingsToggle("Vendas recusadas", isOn: $dm.notifyRefused, key: "notifyRefused")
                    settingsToggle("Vendas reembolsadas", isOn: $dm.notifyRefunded, key: "notifyRefunded")
                }

                // Notification format
                settingsCard {
                    settingsHeader("Formato da Notificação", icon: "text.bubble.fill")
                    HStack {
                        Text("Valor exibido").font(.system(size: 13)).foregroundColor(.mgText)
                        Spacer()
                        Picker("", selection: $dm.valueDisplay) {
                            Text("Líquido").tag("net")
                            Text("Bruto").tag("gross")
                            Text("Esconder").tag("hidden")
                        }
                        .pickerStyle(.menu)
                        .tint(.mgAccent)
                        .onChange(of: dm.valueDisplay) { v in Task { await dm.updatePreference("valueDisplay", value: v) } }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    Divider().padding(.leading, 16)
                    settingsToggle("Nome do produto", isOn: $dm.showProductName, key: "showProductName")
                    settingsToggle("Campanha (utm_campaign)", isOn: $dm.showCampaignName, key: "showCampaignName")
                }

                // Reports
                settingsCard {
                    settingsHeader("Relatórios Agendados", icon: "clock.fill")
                    Text("Receba um resumo de vendas nos horários selecionados")
                        .font(.system(size: 11)).foregroundColor(.mgText3)
                        .padding(.horizontal, 16).padding(.bottom, 4)
                    settingsToggle("08:00", isOn: $dm.reportAt08, key: "reportAt08")
                    settingsToggle("12:00", isOn: $dm.reportAt12, key: "reportAt12")
                    settingsToggle("18:00", isOn: $dm.reportAt18, key: "reportAt18")
                    settingsToggle("23:00", isOn: $dm.reportAt23, key: "reportAt23")
                }

                // Device info
                settingsCard {
                    settingsHeader("Dispositivo", icon: "iphone")
                    infoRow("Nome", UIDevice.current.name)
                    infoRow("Ambiente", DeviceManager.apnsEnvironment == "production" ? "Produção" : "Sandbox")
                    infoRow("Versão", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }

                // Re-pair
                Button(action: { dm.unpair() }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13))
                        Text("Parear novamente")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.mgRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.mgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.mgRed.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(16)
        }
        .background(Color.mgBg)
        .navigationTitle("Ajustes")
        .onAppear { Task { await dm.fetchPreferences() } }
    }

    // MARK: - Settings Components

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(Color.mgCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mgBorder, lineWidth: 1))
    }

    private func settingsHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.mgAccent)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.mgText)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private func settingsToggle(_ label: String, isOn: Binding<Bool>, key: String) -> some View {
        VStack(spacing: 0) {
            Toggle(isOn: isOn) {
                Text(label).font(.system(size: 13)).foregroundColor(.mgText)
            }
            .tint(.mgAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .onChange(of: isOn.wrappedValue) { val in
                Task { await dm.updatePreference(key, value: val) }
            }
            Divider().padding(.leading, 16)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.system(size: 13)).foregroundColor(.mgText)
                Spacer()
                Text(value).font(.system(size: 12, design: .monospaced)).foregroundColor(.mgText3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider().padding(.leading, 16)
        }
    }
}
