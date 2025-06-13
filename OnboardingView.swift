//
//  OnboardingView.swift
//  Kanka
//
//  Created by Furkan BAYINDIR on 02.05.2025.
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn
import Firebase
import CryptoKit
import FirebaseFunctions

// MARK: - OnboardingView
struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("userLanguage") private var selectedLanguage = "tr"
    @AppStorage("userId") private var userId = ""
    @Binding var isAuthenticated: Bool
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showingLanguageSheet = false
    @State private var isLoading = false
    @State private var currentNonce: String?
    @State private var showFreeChat = false
    // ✅ YENİ EKLEME: Otomatik kapanma için
    @Environment(\.presentationMode) private var presentationMode
    @State private var showSuccessMessage = false
    @State private var successMessage = ""

    private var design: NeoDesign {
        NeoDesign(colorScheme: colorScheme)
    }

    private let languages = [
        ("en", "English"), ("tr", "Türkçe"), ("hi", "हिन्दी"),
        ("zh", "中文"), ("it", "Italiano"), ("fr", "Français"),
        ("de", "Deutsch"), ("es", "Español"), ("pt", "Português"),
        ("ru", "Русский"), ("ar", "العربية"), ("ja", "日本語"),
        ("ko", "한국어"), ("nl", "Nederlands"), ("sv", "Svenska"),
        ("no", "Norsk"), ("da", "Dansk"), ("fi", "Suomi"),
        ("pl", "Polski"), ("cs", "Čeština")
    ]
    
    private var selectedLanguageName: String {
        languages.first { $0.0 == selectedLanguage }?.1 ?? "Select"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Simple background
                design.backgroundView
                
                VStack(spacing: 0) {
                    // Top spacer
                    Spacer()
                        .frame(height: geometry.safeAreaInsets.top + 40)
                    
                    // Header with language selector
                    headerSection
                    
                    Spacer()
                    
                    // Main content
                    mainContent
                    
                    Spacer()
                    Spacer()
                }
                
                // Loading overlay
                if isLoading {
                    loadingOverlay
                }
                // ✅ EKLEME: Başarı mesajı overlay
                if showSuccessMessage {
                    successOverlay
                }
            
                
            }
            .ignoresSafeArea(.all)
            .onAppear {
                handleDeviceBlockedAlert()
            }
        }
        .sheet(isPresented: $showingLanguageSheet) {
            languageSelector
        }
        .alert(isPresented: $showAlert) {
            createAlert()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            // App logo and name (OfflineView stilinde)
            HStack(spacing: 16) {
                // Logo icon with OfflineView style
                ZStack {
                    Circle()
                        .fill(design.neonGlow)
                        .frame(width: 45, height: 45)
                        .blur(radius: 10)
                    
                    Circle()
                        .fill(design.glassBackground)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(design.neonText)
                }
                
                Text("Kankam")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(design.primaryText)
            }
            
            Spacer()
            
            // Language selector (OfflineView stilinde)
            Button(action: {
                showingLanguageSheet = true
            }) {
                HStack(spacing: 8) {
                    Text("🌐")
                        .font(.system(size: 16))
                    
                    Text(selectedLanguageName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(design.primaryText)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(design.subtleText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(design.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .cornerRadius(20)
                .shadow(color: design.shadowColor.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Main Content -
    private var mainContent: some View {
        VStack(spacing: 32) {
            // Welcome section
            VStack(spacing: 16) {
                Text(Translations.localizedString(
                    lang: selectedLanguage,
                    section: "onboarding",
                    key: "welcome"
                ))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(design.headingGradient)
                .multilineTextAlignment(.center)
                
                Text(Translations.localizedString(
                    lang: selectedLanguage,
                    section: "onboarding",
                    key: "subtitle"
                ))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(design.subtleText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            }
            
            // Auth buttons with divider
            VStack(spacing: 16) {
                appleSignInButton
                googleSignInButton
                
                // Divider with localized text
                HStack {
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                    Text(Translations.localizedString(
                        lang: selectedLanguage,
                        section: "onboarding",
                        key: "orDivider"
                    ))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                }
                .padding(.horizontal)
                
                // Anonymous Trial Button with localized text
                Button(Translations.localizedString(
                    lang: selectedLanguage,
                    section: "onboarding",
                    key: "freeTrialButton"
                )) {
                    startAnonymousTrial()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.orange, .pink]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            
            // Legal agreement text
            agreementText
            
            // Legal links
            legalLinks
        }
    }

    // Add this new function inside the OnboardingView struct
    private func startAnonymousTrial() {
        // Device check
        let deviceID = DeviceIDManager.id
        let trialKey = "anonymous_trial_used_\(deviceID)"
        
        if UserDefaults.standard.bool(forKey: trialKey) {
            alertTitle = Translations.localizedString(
                lang: selectedLanguage,
                section: "onboarding",
                key: "trialUsedTitle"
            )
            alertMessage = Translations.localizedString(
                lang: selectedLanguage,
                section: "onboarding",
                key: "trialUsedMessage"
            )
            showAlert = true
            return
        }
        
        isLoading = true
        
        // Firebase Anonymous Auth
        Auth.auth().signInAnonymously { [self] authResult, error in
            isLoading = false
            
            if let error = error {
                alertTitle = Translations.localizedString(
                    lang: selectedLanguage,
                    section: "onboarding",
                    key: "errorTitle"
                )
                alertMessage = error.localizedDescription
                showAlert = true
                return
            }
            
            guard let user = authResult?.user else { return }
            
            // Mark trial as used
            UserDefaults.standard.set(true, forKey: trialKey)
            UserDefaults.standard.set(Date().addingTimeInterval(3 * 24 * 60 * 60), forKey: "trial_end_date")
            
            userId = user.uid
            UserDefaults.standard.set(user.uid, forKey: "userId")
            
            // Save as trial user in Firestore
            saveTrialUser(user: user)
            
            isAuthenticated = true
            authManager.isAuthenticated = true
            // ✅ YENİ EKLEME: Anonymous trial başarılı sonrası otomatik kapanma
            showSuccessWithAutoDismiss(message: "Ücretsiz deneme başladı!")
        }
    }

    private func saveTrialUser(user: User) {
        let db = Firestore.firestore()
        let trialEndDate = UserDefaults.standard.object(forKey: "trial_end_date") as? Date ?? Date()
        
        let userData: [String: Any] = [
            "id": user.uid,
            "email": "",
            "fullName": "Deneme Kullanıcısı",
            "authMethod": "anonymous",
            "createdAt": FieldValue.serverTimestamp(),
            "lastLogin": FieldValue.serverTimestamp(),
            "language": selectedLanguage,
            "deviceID": DeviceIDManager.id,
            "plan": "trial",
            "tokensRemaining": 1000, // 3 günlük limit
            "resetAt": Timestamp(date: trialEndDate),
            "isAnonymous": true,
            "trialEndDate": Timestamp(date: trialEndDate)
        ]
        
        db.collection("users").document(user.uid).setData(userData, merge: true)
    }
    
    // MARK: - Agreement Text (OfflineView cam efekti stilinde)
    private var agreementText: some View {
        Text(Translations.localizedString(
            lang: selectedLanguage,
            section: "onboarding",
            key: "legalAgreement"
        ))
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(design.primaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            ZStack {
                design.glassBackground
                
                // Üst parlama efekti
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.7),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .cornerRadius(16)
        .shadow(color: design.shadowColor, radius: 15, x: 0, y: 3)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Legal Links (OfflineView stilinde subtle)
    private var legalLinks: some View {
        HStack(spacing: 24) {
            Button(action: {
                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    UIApplication.shared.open(url)
                }
            }) {
                Text(Translations.localizedString(
                    lang: selectedLanguage,
                    section: "onboarding",
                    key: "termsOfUse"
                ))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(design.primaryColor)
                .underline()
            }
            .buttonStyle(ScaleButtonStyle())
            
            Text("•")
                .font(.system(size: 13))
                .foregroundColor(design.subtleText)
            
            Button(action: {
                if let url = URL(string: "https://kankachat.com/privacy-policy.html") {
                    UIApplication.shared.open(url)
                }
            }) {
                Text(Translations.localizedString(
                    lang: selectedLanguage,
                    section: "onboarding",
                    key: "privacyPolicy"
                ))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(design.primaryColor)
                .underline()
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 10)
    }
    
    // MARK: - Apple Sign In Button (OfflineView stiline uygun)
    private var appleSignInButton: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: configureAppleSignInRequest,
            onCompletion: handleAppleSignInCompletion
        )
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 56)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(design.buttonBorder, lineWidth: 1)
        )
        .shadow(color: design.shadowColor, radius: 15, x: 0, y: 5)
    }
    
    // MARK: - Google Sign In Button (OfflineView stilinde)
    private var googleSignInButton: some View {
        Button(action: googleSignIn) {
            HStack(spacing: 12) {
                // ✅ DÜZELTİLMİŞ: Asset yerine SF Symbol kullanıyoruz
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(Translations.localizedString(
                    lang: selectedLanguage,
                    section: "onboarding",
                    key: "continueWithGoogle"
                ))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    LinearGradient(
                        gradient: design.buttonGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.3), Color.clear]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 150
                    )
                }
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(design.buttonBorder, lineWidth: 1)
            )
            .shadow(color: design.buttonShadow, radius: 15, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Loading Overlay (OfflineView stilinde)
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(Translations.localizedString(
                    lang: selectedLanguage,
                    section: "onboarding",
                    key: "signingIn"
                ))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            }
            .padding(32)
            .background(
                ZStack {
                    design.glassBackground
                    
                    // Üst parlama efekti
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .cornerRadius(20)
            .shadow(color: design.shadowColor, radius: 25, x: 0, y: 10)
        }
    }
    
    // MARK: - Language Selector
    private var languageSelector: some View {
        ChatLanguageSelectorView(
            selectedLanguage: $selectedLanguage,
            languages: languages,
            design: design
        )
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationBackground(design.contentBackground)
        .presentationCornerRadius(30)
    }
    
    // MARK: - Helper Functions
    
    // ✅ YENİ EKLEME: Başarı mesajı overlay'i
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 20) {
                // Başarı iconu
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text(successMessage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Text("Ana ekrana yönlendiriliyorsunuz...")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(design.glassBackground)
            )
            .padding(.horizontal, 40)
        }
    }
    // OnboardingView.swift'te handleSuccessfulAuth fonksiyonunu güncelleyin:
    private func handleSuccessfulAuth(authMethod: String) {
        let message = authMethod == "google" ?
            "Google ile giriş başarılı! Premium'a yönlendiriliyorsunuz..." :
            authMethod == "apple" ?
            "Apple ile giriş başarılı! Premium'a yönlendiriliyorsunuz..." :
            "Giriş başarılı! Premium'a yönlendiriliyorsunuz..."
        
        showSuccessWithAutoDismiss(message: message)
    }

    private func showSuccessWithAutoDismiss(message: String) {
        successMessage = message
        showSuccessMessage = true
        
        // 1.5 saniye sonra otomatik kapan (premium flow için optimize)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismissOnboarding()
        }
    }

    private func dismissOnboarding() {
        // OnboardingView'ı kapat
        showSuccessMessage = false
        isAuthenticated = true
    }
    
    private func handleDeviceBlockedAlert() {
        if UserDefaults.standard.bool(forKey: "deviceBlocked") {
            alertTitle = "Hesap Sınırlaması"
            alertMessage = """
            Bu cihazdan en fazla 2 hesapla giriş yapılabilir.
            Daha önce kullandığın hesaba dön
            veya Premium'a geç.
            """
            showAlert = true
            UserDefaults.standard.removeObject(forKey: "deviceBlocked")
        }
    }
    
    private func createAlert() -> Alert {
        Alert(
            title: Text(alertTitle),
            message: Text(alertMessage),
            primaryButton: .default(Text("Tamam")) {
                handleAlertDismissal()
            },
            secondaryButton: .cancel(Text("İptal"))
        )
    }
    
    private func handleAlertDismissal() {
        do {
            try Auth.auth().signOut()
            userId = ""
            UserDefaults.standard.removeObject(forKey: "userId")
            isAuthenticated = false
            
            if UserDefaults.standard.bool(forKey: "deviceBlocked") {
                UserDefaults.standard.removeObject(forKey: "deviceBlocked")
            }
        } catch {
            print("❌ Error signing out:", error.localizedDescription)
        }
    }
    
    // MARK: - Authentication Functions
    
    private func googleSignIn() {
        // ✅ DÜZELTİLMİŞ: Mevcut key window'u buluyoruz
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            print("⚠️ Root view controller not found")
            alertTitle = "Hata"
            alertMessage = "Giriş işlemi için gerekli bileşen bulunamadı"
            showAlert = true
            return
        }
        
        isLoading = true
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [self] result, error in
            isLoading = false
            
            if let error = error {
                alertTitle = Translations.localizedString(
                    lang: selectedLanguage,
                    section: "onboarding",
                    key: "googleSignInErrorTitle"
                )
                alertMessage = error.localizedDescription
                showAlert = true
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            let fullName = user.profile?.name ?? ""
            
            Auth.auth().signIn(with: credential) { [self] authResult, error in
                if let error = error {
                    alertTitle = Translations.localizedString(
                        lang: selectedLanguage,
                        section: "onboarding",
                        key: "authErrorTitle"
                    )
                    alertMessage = error.localizedDescription
                    showAlert = true
                    return
                }
                
                guard let firebaseUser = authResult?.user else { return }
                
                userId = firebaseUser.uid
                UserDefaults.standard.set(firebaseUser.uid, forKey: "userId")
                print("OnboardingView: Saved user ID to local storage: \(firebaseUser.uid)")
                
                saveUserToFirestore(
                    user: firebaseUser,
                    authMethod: "google",
                    fullName: fullName
                )
            }
        }
    }
    
    private func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    private func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            handleAppleSignIn(result: authResults)
        case .failure(let error):
            alertTitle = Translations.localizedString(
                lang: selectedLanguage,
                section: "onboarding",
                key: "appleSignInErrorTitle"
            )
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    private func handleAppleSignIn(result: ASAuthorization) {
        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("⚠️ Apple Sign-In credential error")
            return
        }
        
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce,
            accessToken: nil
        )
        
        isLoading = true
        
        Auth.auth().signIn(with: credential) { [self] authResult, error in
            isLoading = false
            
            if let error = error {
                alertTitle = Translations.localizedString(
                    lang: selectedLanguage,
                    section: "onboarding",
                    key: "authErrorTitle"
                )
                alertMessage = error.localizedDescription
                showAlert = true
                return
            }
            
            guard let user = authResult?.user else { return }
            
            let fullName = [
                appleIDCredential.fullName?.givenName,
                appleIDCredential.fullName?.familyName
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            
            userId = user.uid
            print("OnboardingView: Saved Apple user ID to local storage: \(user.uid)")
            
            DispatchQueue.main.async {
                authManager.isAuthenticated = true
            }
            
            saveUserToFirestore(user: user, authMethod: "apple", fullName: fullName)
        }
    }
    
    private func saveUserToFirestore(user: User, authMethod: String, fullName: String? = nil) {
        print("🔍 saveUserToFirestore CALLED → uid:", user.uid, "authMethod:", authMethod)
        
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(user.uid)
        print("📂 Writing to path:", docRef.path)
        
        let deviceID = DeviceIDManager.id
        print("📱 Device ID:", deviceID)
        
        print("📞 Calling registerDevice for deviceID:", deviceID)
        let functions = Functions.functions()
        functions.httpsCallable("registerDevice").call(["deviceID": deviceID]) { result, error in
            if let error = error {
                print("❌ Device registration error:", error.localizedDescription)
                DispatchQueue.main.async {
                    self.alertTitle = "Hata"
                    self.alertMessage = "Hesap kontrolü yapılırken bir hata oluştu: \(error.localizedDescription)"
                    self.showAlert = true
                }
                return
            }
            
            print("✅ Device registration result:", result?.data ?? "nil")
            
            if let data = result?.data as? [String: Any] {
                let isBlocked = data["isBlocked"] as? Bool ?? false
                
                if isBlocked {
                    print("🚫 Account blocked: Max accounts reached for this device")
                    
                    DispatchQueue.main.async {
                        self.alertTitle = "Hesap Sınırlaması"
                        self.alertMessage = """
                        Bu cihazdan günde en fazla 2 hesapla giriş yapabilirsiniz.
                        Daha önce kullandığın hesaba dön
                        veya Premium'a geç.
                        """
                        self.showAlert = true
                        UserDefaults.standard.set(true, forKey: "deviceBlocked")
                    }
                    return
                }
                
                let userData: [String: Any] = [
                    "id": user.uid,
                    "email": user.email ?? "",
                    "fullName": fullName ?? user.displayName ?? "",
                    "authMethod": authMethod,
                    "createdAt": FieldValue.serverTimestamp(),
                    "lastLogin": FieldValue.serverTimestamp(),
                    "photoURL": user.photoURL?.absoluteString ?? "",
                    "language": self.selectedLanguage,
                    "deviceID": deviceID,
                    "plan": "free",
                    "tokensRemaining": 2500,
                    "resetAt": Timestamp(
                        date: Calendar.current
                            .startOfDay(for: Date())
                            .addingTimeInterval(86_400)
                    ),
                    "limitedAccount": false
                ]
                
                docRef.setData(userData, merge: true) { error in
                    if let error = error {
                        print("❌ Firestore write failed:", error.localizedDescription)
                        return
                    }
                    print("✅ User saved →", docRef.path)
                    
                    // ✅ YENİ HAL:
                    DispatchQueue.main.async {
                        self.isAuthenticated = true
                        self.hasCompletedOnboarding = true
                        
                        // ✅ YENİ EKLEME: Başarılı kayıt sonrası otomatik kapanma
                        self.handleSuccessfulAuth(authMethod: authMethod)
                    }
                }
            }
        }
    }
    
    
    // MARK: - Crypto Functions
    
    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            randoms.forEach { random in
                if remainingLength > 0 && random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let hashedData = SHA256.hash(data: Data(input.utf8))
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}


// MARK: - Preview
#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isAuthenticated: .constant(false))
            .environmentObject(AuthManager.shared)
            .preferredColorScheme(.light)
        
        OnboardingView(isAuthenticated: .constant(false))
            .environmentObject(AuthManager.shared)
            .preferredColorScheme(.dark)
    }
}
#endif
