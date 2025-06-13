//
//  SubscriptionManager.swift
//  Kanka
//
//  Created by Furkan BAYINDIR on 19.05.2025.
//

import SwiftUI
import StoreKit
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

// MARK: - SubscriptionStatus Enum
enum SubscriptionStatus {
    case loading
    case notPurchased
    case purchased
    case expired
    case revoked
    case inGracePeriod
    case pending
}

// MARK: - StoreKit Errors
enum StoreKitError: Error, LocalizedError {
    case productNotFound
    case userCancelled
    case unknown
    case paymentNotAllowed
    case networkError
    case verificationFailed
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Ürün bulunamadı."
        case .userCancelled:
            return "Satın alma iptal edildi."
        case .unknown:
            return "Bilinmeyen bir hata oluştu."
        case .paymentNotAllowed:
            return "Bu cihazda ödeme yapılamıyor."
        case .networkError:
            return "Ağ bağlantısı hatası. Lütfen internet bağlantınızı kontrol edin."
        case .verificationFailed:
            return "Satın alma doğrulaması başarısız oldu."
        }
    }
}

// MARK: - SubscriptionManager
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    private let premiumMonthlyID = "premium.monthly"
    
    @Published var status: SubscriptionStatus = .loading
    @Published var product: Product?
    @Published var expirationDate: Date?
    // ← BURAYA EKLE:
        var isPremium: Bool {
            status == .purchased || status == .inGracePeriod
        }
    
    private var updateListenerTask: Task<Void, Error>?
    private var currentUserId: String?
    
    init() {
        // Auth state change listener ekle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(authStateChanged),
            name: .AuthStateDidChange,
            object: nil
        )
        
        // Transactions listener'ı başlat
        updateListenerTask = listenForTransactions()
        
        // Ürünleri yükle
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Auth State Changed
    @objc private func authStateChanged() {
        if let newUserId = Auth.auth().currentUser?.uid {
            if currentUserId != newUserId {
                print("🔄 Kullanıcı değişti: \(currentUserId ?? "nil") -> \(newUserId)")
                currentUserId = newUserId
                
                // Durumu sıfırla
                status = .loading
                expirationDate = nil
                
                // Yeniden kontrol et
                Task {
                    await updateSubscriptionStatus()
                }
            }
        } else {
            // Kullanıcı çıkış yaptı
            print("👋 Kullanıcı çıkış yaptı")
            currentUserId = nil
            status = .notPurchased
            expirationDate = nil
        }
    }
    
    // MARK: - Ürün Yükleme
    @MainActor
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [premiumMonthlyID])
            
            if let premiumProduct = products.first {
                self.product = premiumProduct
                print("✅ Ürün yüklendi: \(premiumProduct.displayName), Fiyat: \(premiumProduct.displayPrice)")
            }
        } catch {
            print("❌ Ürünler yüklenirken hata: \(error)")
        }
    }
    
    // MARK: - Transactions Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.verifyTransaction(result)
                    
                    await MainActor.run {
                        print("📱 Yeni transaction: \(transaction.productID)")
                    }
                    
                    // Abonelik durumunu güncelle
                    await self.updateSubscriptionStatus()
                    
                    // İşlemi tamamla
                    await transaction.finish()
                    
                } catch {
                    print("❌ Transaction doğrulama hatası: \(error)")
                }
            }
        }
    }
    
    // MARK: - Transaction Verification
    private func verifyTransaction(_ result: VerificationResult<StoreKit.Transaction>) throws -> StoreKit.Transaction {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let transaction):
            return transaction
        }
    }
    
    // MARK: - GÜNCELLENMIŞ: Sadece StoreKit Kontrolü
    // ✅ GÜNCELLENMIŞ: updateSubscriptionStatus fonksiyonu
    @MainActor
    func updateSubscriptionStatus() async {
        guard let currentUser = Auth.auth().currentUser else {
            status = .notPurchased
            return
        }
        
        // ✅ YENİ EKLEME: Anonymous kullanıcılar için premium engelle
        if currentUser.isAnonymous {
            print("🎭 Anonymous user - premium disabled")
            status = .notPurchased
            expirationDate = nil
            return
        }
        
        // ✅ YENİ EKLEME: Fresh account sonrası ilk giriş kontrolü
        if UserDefaults.standard.bool(forKey: "accountDeleted") {
            print("🗑️ Fresh account after deletion - ignoring old receipts")
            status = .notPurchased
            expirationDate = nil
            
            // Bu flag'i 24 saat sonra otomatik kaldır
            DispatchQueue.main.asyncAfter(deadline: .now() + 86400) {
                UserDefaults.standard.removeObject(forKey: "accountDeleted")
                print("🕐 Account deletion flag expired")
            }
            return
        }
        
        // Normal StoreKit kontrolü (mevcut kod...)
        var hasActiveSubscription = false
        
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == premiumMonthlyID {
                    hasActiveSubscription = true
                    self.status = .purchased
                    self.expirationDate = transaction.expirationDate
                    
                    print("✅ Aktif abonelik bulundu: \(transaction.productID)")
                    await syncToFirebase(isPremium: true)
                    break
                }
            }
        }
        
        if !hasActiveSubscription {
            self.status = .notPurchased
            self.expirationDate = nil
            await syncToFirebase(isPremium: false)
        }
    }
    
    // syncToFirebase fonksiyonu - DÜZELTILMIŞ
    private func syncToFirebase(isPremium: Bool) async {
        guard (Auth.auth().currentUser?.uid) != nil else { return }
        
        let functions = Functions.functions(region: "us-central1") // Region belirtildi
        
        do {
            var data: [String: Any] = ["isPremium": isPremium]
            
            // Expiration date'i millisaniye olarak ekle
            if let expDate = expirationDate {
                data["expirationDate"] = Int(expDate.timeIntervalSince1970 * 1000)
            }
            
            // Fonksiyonu çağır
            let callable = functions.httpsCallable("syncUserPlan")
            let result = try await callable.call(data)
            
            if let resultData = result.data as? [String: Any],
               let success = resultData["success"] as? Bool {
                print("✅ Firebase sync: \(success ? "Başarılı" : "Başarısız")")
            }
        } catch {
            print("⚠️ Firebase sync hatası: \(error)")
            // Hata olsa bile uygulama çalışmaya devam eder
        }
    }
    
    // MARK: - Satın Alma
    @MainActor
    func purchase() async throws {
        guard let product = self.product else {
            throw StoreKitError.productNotFound
        }
        
        // Satın alma isteği
        let result = try await product.purchase()
        
        switch result {
        case .success(let verificationResult):
            // İşlemi doğrula
            let transaction = try verifyTransaction(verificationResult)
            
            // Transaction'ı bitir
            await transaction.finish()
            
            // Status'ü hemen güncelle
            await updateSubscriptionStatus()
            
            print("✅ Satın alma tamamlandı!")
            
        case .userCancelled:
            throw StoreKitError.userCancelled
            
        case .pending:
            self.status = .pending
            
        @unknown default:
            throw StoreKitError.unknown
        }
    }
    
    // MARK: - Satın Almaları Geri Yükleme
    @MainActor
    func restorePurchases() async throws {
        // AppStore ile senkronize et
        try await AppStore.sync()
        
        // Status'u güncelle
        await updateSubscriptionStatus()
    }
    
    // MARK: - Grace Period Kontrolü (Opsiyonel)
    func checkGracePeriod() async -> Bool {
        // Eğer Firebase'de premium görünüyor ama StoreKit'te yoksa
        // 3 gün grace period ver (offline durumlar için)
        
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        let db = Firestore.firestore()
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            if let data = doc.data(),
               let plan = data["plan"] as? String,
               plan == "premium",
               let lastSync = data["lastSyncDate"] as? Timestamp {
                
                // Son senkronizasyondan 3 gün geçmemişse grace period
                let daysSinceSync = Calendar.current.dateComponents([.day],
                    from: lastSync.dateValue(),
                    to: Date()).day ?? 0
                
                return daysSinceSync < 3
            }
        } catch {
            print("❌ Grace period kontrol hatası: \(error)")
        }
        
        return false
    }
    
    // MARK: - Debug Helper
    func debugSubscriptionStatus() {
        Task {
            print("\n🔍 === ABONELIK DEBUG ===")
            print("📱 Status: \(status)")
            print("📅 Bitiş: \(expirationDate?.description ?? "nil")")
            
            // Tüm transaction'ları listele
            print("\n📜 Aktif Abonelikler:")
            for await result in StoreKit.Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    print("   - \(transaction.productID): \(transaction.expirationDate?.description ?? "süresiz")")
                }
            }
            print("========================\n")
        }
    }
}
