import Foundation
import Combine
import UIKit

@MainActor
class DeviceManager: ObservableObject {
    static let shared = DeviceManager()

    // Server base URL
    let baseURL: String = "https://manager-7ls2.onrender.com/api/push"

    @Published var deviceToken: String = ""
    @Published var isPaired: Bool = UserDefaults.standard.bool(forKey: "isPaired")
    @Published var pairingError: String = ""
    @Published var isLoading: Bool = false

    // Preferences
    @Published var notifyPending: Bool = true
    @Published var notifyApproved: Bool = true
    @Published var notifyRefused: Bool = false
    @Published var notifyRefunded: Bool = false
    @Published var valueDisplay: String = "net" // "net" | "gross" | "hidden"
    @Published var showProductName: Bool = false
    @Published var showCampaignName: Bool = false
    @Published var reportAt08: Bool = false
    @Published var reportAt12: Bool = true
    @Published var reportAt18: Bool = true
    @Published var reportAt23: Bool = true

    private init() {
        loadPreferencesFromLocal()
    }

    // MARK: - Pairing

    func pairWithCode(_ code: String) async {
        guard !deviceToken.isEmpty else {
            pairingError = "Token do dispositivo não disponível. Verifique as permissões de notificação."
            return
        }

        isLoading = true
        pairingError = ""

        guard let url = URL(string: "\(baseURL)/register") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "deviceToken": deviceToken,
            "pairingCode": code,
            "name": UIDevice.current.name
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            if httpResponse?.statusCode == 200 {
                isPaired = true
                UserDefaults.standard.set(true, forKey: "isPaired")
                await fetchPreferences()
            } else {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                pairingError = (json?["error"] as? String) ?? "Erro ao parear"
            }
        } catch {
            pairingError = "Erro de conexão: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func registerWithServer() async {
        guard !deviceToken.isEmpty else { return }

        guard let url = URL(string: "\(baseURL)/register") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let stored = UserDefaults.standard.string(forKey: "pairingCode") ?? ""
        let body: [String: Any] = [
            "deviceToken": deviceToken,
            "pairingCode": stored,
            "name": UIDevice.current.name
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Preferences

    func fetchPreferences() async {
        guard !deviceToken.isEmpty else { return }

        guard let url = URL(string: "\(baseURL)/preferences/\(deviceToken)") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                notifyPending = json["notifyPending"] as? Bool ?? true
                notifyApproved = json["notifyApproved"] as? Bool ?? true
                notifyRefused = json["notifyRefused"] as? Bool ?? false
                notifyRefunded = json["notifyRefunded"] as? Bool ?? false
                valueDisplay = json["valueDisplay"] as? String ?? "net"
                showProductName = json["showProductName"] as? Bool ?? false
                showCampaignName = json["showCampaignName"] as? Bool ?? false
                reportAt08 = json["reportAt08"] as? Bool ?? false
                reportAt12 = json["reportAt12"] as? Bool ?? true
                reportAt18 = json["reportAt18"] as? Bool ?? true
                reportAt23 = json["reportAt23"] as? Bool ?? true
                savePreferencesLocally()
            }
        } catch {
            print("[Prefs] fetch error: \(error.localizedDescription)")
        }
    }

    func updatePreference(_ key: String, value: Any) async {
        guard !deviceToken.isEmpty else { return }

        // Save locally first
        savePreferencesLocally()

        guard let url = URL(string: "\(baseURL)/preferences/\(deviceToken)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [key: value]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Local Storage

    private func savePreferencesLocally() {
        let defaults = UserDefaults.standard
        defaults.set(notifyPending, forKey: "notifyPending")
        defaults.set(notifyApproved, forKey: "notifyApproved")
        defaults.set(notifyRefused, forKey: "notifyRefused")
        defaults.set(notifyRefunded, forKey: "notifyRefunded")
        defaults.set(valueDisplay, forKey: "valueDisplay")
        defaults.set(showProductName, forKey: "showProductName")
        defaults.set(showCampaignName, forKey: "showCampaignName")
        defaults.set(reportAt08, forKey: "reportAt08")
        defaults.set(reportAt12, forKey: "reportAt12")
        defaults.set(reportAt18, forKey: "reportAt18")
        defaults.set(reportAt23, forKey: "reportAt23")
    }

    private func loadPreferencesFromLocal() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "notifyPending") != nil {
            notifyPending = defaults.bool(forKey: "notifyPending")
            notifyApproved = defaults.bool(forKey: "notifyApproved")
            notifyRefused = defaults.bool(forKey: "notifyRefused")
            notifyRefunded = defaults.bool(forKey: "notifyRefunded")
            valueDisplay = defaults.string(forKey: "valueDisplay") ?? "net"
            showProductName = defaults.bool(forKey: "showProductName")
            showCampaignName = defaults.bool(forKey: "showCampaignName")
            reportAt08 = defaults.bool(forKey: "reportAt08")
            reportAt12 = defaults.bool(forKey: "reportAt12")
            reportAt18 = defaults.bool(forKey: "reportAt18")
            reportAt23 = defaults.bool(forKey: "reportAt23")
        }
    }
}
