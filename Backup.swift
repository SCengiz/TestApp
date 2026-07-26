import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Tüm verilerin tek bir JSON dosyasına alınması ve geri yüklenmesi.
//
// Amaç: uygulama telefondan silinirse ya da kullanıcı yeni bir hesaba geçmek
// isterse hiçbir şey kaybolmasın. Yedek dosyası okunabilir JSON'dur; kullanıcı
// Dosyalar'a kaydedebilir, iCloud'a atabilir, kendine gönderebilir.
//
// BİLEREK DIŞARIDA BIRAKILANLAR: giriş şifresi ve yapay zeka API anahtarı.
// İkisi de kimlik bilgisi; paylaşılabilecek düz bir dosyaya yazılmazlar.

// MARK: - Dosya biçimi

struct BackupFile: Codable {
    var format = BackupService.formatID
    var version = BackupService.formatVersion
    var createdAt = Date.now
    var user: String
    var settings: BackupSettings
    var expenses: [BackupExpense] = []
    var incomes: [BackupIncome] = []
    var incomeSnapshots: [BackupMonthTotal] = []
    var payments: [BackupPayment] = []
    var paidPayments: [BackupPaidPayment] = []
    var paymentMonthAmounts: [BackupMonthAmount] = []
    var accounts: [BackupAccount] = []
    var savingsSnapshots: [BackupMonthTotal] = []
    var debts: [BackupDebt] = []
    var expenseCategories: [BackupCategory] = []
    var paymentCategories: [BackupPaymentCategory] = []
}

struct BackupSettings: Codable {
    var avatarID: String?
    var appTheme: String?
    var appLanguage: String?
    var hideIncomeAmounts: Bool?
    var aiModelName: String?
}

struct BackupExpense: Codable {
    var title: String
    var amount: Double
    var date: Date
    var category: String
    var installmentCount: Int?
    var installmentNumber: Int?
    var installmentGroupID: UUID?
}

struct BackupIncome: Codable {
    var name: String
    var amount: Double
}

struct BackupMonthTotal: Codable {
    var monthStart: Date
    var total: Double
}

struct BackupPayment: Codable {
    var name: String
    var amount: Double
    var dueDay: Int
    var category: String
    var totalInstallments: Int?
    var firstPaymentDate: Date?
}

struct BackupPaidPayment: Codable {
    var paymentName: String
    var monthStart: Date
    var paidAt: Date
}

struct BackupMonthAmount: Codable {
    var paymentName: String
    var monthStart: Date
    var amount: Double
}

struct BackupAccount: Codable {
    var name: String
    var kind: String
    var createdAt: Date
    var assets: [BackupAsset]
}

struct BackupAsset: Codable {
    var accountKind: String
    var name: String
    var code: String?
    var unitPrice: Double
    var priceUpdatedAt: Date?
    var transactions: [BackupTransaction]
}

struct BackupTransaction: Codable {
    var date: Date
    var quantity: Double
    var pricePerUnit: Double?
    var interestRate: Double?
}

struct BackupDebt: Codable {
    var name: String
    var kind: String
    var quantity: Double
    var date: Date
    var lastKnownRate: Double
    var initialRate: Double?
}

struct BackupCategory: Codable {
    var name: String
    var icon: String
    var colorName: String
    var createdAt: Date
}

struct BackupPaymentCategory: Codable {
    var name: String
    var icon: String
    var colorName: String
    var amountVaries: Bool
    var createdAt: Date
}

// Geri yüklemeden önce kullanıcıya "bu yedekte ne var" diye gösterilen sayım
struct BackupContents {
    var user: String
    var createdAt: Date
    var expenses: Int
    var payments: Int
    var incomes: Int
    var accounts: Int
    var debts: Int
    var categories: Int

    var isEmpty: Bool {
        expenses + payments + incomes + accounts + debts + categories == 0
    }
}

enum BackupError: LocalizedError {
    case unreadable
    case wrongFormat
    case tooNew

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return tr("Dosya okunamadı. Bu bir İyi Bütçe yedeği mi?",
                      "Could not read the file. Is it an İyi Bütçe backup?")
        case .wrongFormat:
            return tr("Bu dosya bir İyi Bütçe yedeği değil.",
                      "This file is not an İyi Bütçe backup.")
        case .tooNew:
            return tr("Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. Önce uygulamayı güncelle.",
                      "This backup was made with a newer version of the app. Update the app first.")
        }
    }
}

// MARK: - Servis

@MainActor
enum BackupService {
    static let formatID = "iyibutce-yedek"
    static let formatVersion = 1

    private static var coder: (JSONEncoder, JSONDecoder) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (encoder, decoder)
    }

    // MARK: Dışa aktarma

    static func makeBackup(_ context: ModelContext, user: String) -> BackupFile {
        let defaults = UserDefaults.standard
        var file = BackupFile(
            user: user,
            settings: BackupSettings(
                avatarID: defaults.string(forKey: avatarStorageKey(for: user)),
                appTheme: defaults.string(forKey: "appTheme"),
                appLanguage: defaults.string(forKey: "appLanguage"),
                hideIncomeAmounts: defaults.object(forKey: "hideIncomeAmounts") as? Bool,
                aiModelName: defaults.string(forKey: "aiModelName")
            )
        )

        func all<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }

        file.expenses = all(Expense.self).map {
            BackupExpense(title: $0.title, amount: $0.amount, date: $0.date,
                          category: $0.category, installmentCount: $0.installmentCount,
                          installmentNumber: $0.installmentNumber,
                          installmentGroupID: $0.installmentGroupID)
        }
        file.incomes = all(IncomeSource.self).map {
            BackupIncome(name: $0.name, amount: $0.amount)
        }
        file.incomeSnapshots = all(IncomeSnapshot.self).map {
            BackupMonthTotal(monthStart: $0.monthStart, total: $0.total)
        }
        file.payments = all(FixedPayment.self).map {
            BackupPayment(name: $0.name, amount: $0.amount, dueDay: $0.dueDay,
                          category: $0.category, totalInstallments: $0.totalInstallments,
                          firstPaymentDate: $0.firstPaymentDate)
        }
        file.paidPayments = all(PaidPayment.self).map {
            BackupPaidPayment(paymentName: $0.paymentName, monthStart: $0.monthStart,
                              paidAt: $0.paidAt)
        }
        file.paymentMonthAmounts = all(PaymentMonthAmount.self).map {
            BackupMonthAmount(paymentName: $0.paymentName, monthStart: $0.monthStart,
                              amount: $0.amount)
        }
        file.accounts = all(SavingsAccountModel.self).map { account in
            BackupAccount(
                name: account.name, kind: account.kind, createdAt: account.createdAt,
                assets: account.assets.map { asset in
                    BackupAsset(
                        accountKind: asset.accountKind, name: asset.name, code: asset.code,
                        unitPrice: asset.unitPrice, priceUpdatedAt: asset.priceUpdatedAt,
                        transactions: asset.transactions.map {
                            BackupTransaction(date: $0.date, quantity: $0.quantity,
                                              pricePerUnit: $0.pricePerUnit,
                                              interestRate: $0.interestRate)
                        }
                    )
                }
            )
        }
        file.savingsSnapshots = all(SavingsSnapshot.self).map {
            BackupMonthTotal(monthStart: $0.monthStart, total: $0.total)
        }
        file.debts = all(Debt.self).map {
            BackupDebt(name: $0.name, kind: $0.kind, quantity: $0.quantity, date: $0.date,
                       lastKnownRate: $0.lastKnownRate, initialRate: $0.initialRate)
        }
        file.expenseCategories = all(CustomCategory.self).map {
            BackupCategory(name: $0.name, icon: $0.icon, colorName: $0.colorName,
                           createdAt: $0.createdAt)
        }
        file.paymentCategories = all(CustomPaymentCategory.self).map {
            BackupPaymentCategory(name: $0.name, icon: $0.icon, colorName: $0.colorName,
                                  amountVaries: $0.amountVaries, createdAt: $0.createdAt)
        }
        return file
    }

    // Dosya adında tarih YOK: kullanıcı Dosyalar'da tek bir yedek dosyası tutup
    // her seferinde üzerine yazmak istiyor. Yedeğin ne zaman alındığı dosyanın
    // içindeki createdAt alanında duruyor ve geri yüklerken onay ekranında gösteriliyor.
    // Hesap adı ada giriyor ki farklı hesapların yedekleri birbirini ezmesin.
    static func exportToFile(_ context: ModelContext, user: String) throws -> URL {
        let file = makeBackup(context, user: user)
        let data = try coder.0.encode(file)
        let name = "iyi-butce-\(user).json"
        let temporary = FileManager.default.temporaryDirectory
        // Eski sürümlerden kalan tarihli yedekler geçici klasörde birikmesin
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: temporary.path)) ?? []
        for old in leftovers where old.hasPrefix("iyi-butce") && old != name {
            try? FileManager.default.removeItem(at: temporary.appendingPathComponent(old))
        }
        let url = temporary.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: İçe aktarma

    static func read(_ url: URL) throws -> BackupFile {
        // Dosyalar/iCloud'dan gelen adresler korumalı olabiliyor
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw BackupError.unreadable }
        guard let file = try? coder.1.decode(BackupFile.self, from: data) else {
            throw BackupError.wrongFormat
        }
        guard file.format == formatID else { throw BackupError.wrongFormat }
        guard file.version <= formatVersion else { throw BackupError.tooNew }
        return file
    }

    static func contents(of file: BackupFile) -> BackupContents {
        BackupContents(user: file.user, createdAt: file.createdAt,
                       expenses: file.expenses.count,
                       payments: file.payments.count,
                       incomes: file.incomes.count,
                       accounts: file.accounts.count,
                       debts: file.debts.count,
                       categories: file.expenseCategories.count
                           + file.paymentCategories.count)
    }

    // Mevcut kullanıcının verisini tamamen yedektekiyle değiştirir.
    // Yalnızca kullanıcı onay verdikten sonra çağrılır.
    static func restore(_ file: BackupFile, into context: ModelContext, user: String) throws {
        // 1) Bu kullanıcının deposunu temizle (depo zaten kullanıcıya özel).
        //
        // context.delete(model:) KULLANILMIYOR: toplu silme doğrudan depoya
        // gidiyor, ekranlarda @Query ile yüklü kalan nesneler bağlamda kayıtlı
        // kaldığı için sonraki save bunları geri yazıyor ve kayıtlar ikiye
        // katlanıyordu. Nesneleri tek tek silmek bağlamdan da düşürüyor.
        func wipe<T: PersistentModel>(_ type: T.Type) {
            for object in (try? context.fetch(FetchDescriptor<T>())) ?? [] {
                context.delete(object)
            }
        }
        // Birikim tarafında sıra önemli: önce işlemler, sonra varlıklar, sonra hesaplar
        wipe(AssetTransaction.self)
        wipe(Asset.self)
        wipe(SavingsAccountModel.self)
        wipe(Expense.self)
        wipe(IncomeSource.self)
        wipe(IncomeSnapshot.self)
        wipe(FixedPayment.self)
        wipe(PaidPayment.self)
        wipe(PaymentMonthAmount.self)
        wipe(SavingsSnapshot.self)
        wipe(Debt.self)
        wipe(CustomCategory.self)
        wipe(CustomPaymentCategory.self)
        try context.save()

        // 2) Yedekteki kayıtları yaz
        for item in file.expenses {
            context.insert(Expense(title: item.title, amount: item.amount, date: item.date,
                                   category: item.category,
                                   installmentCount: item.installmentCount,
                                   installmentNumber: item.installmentNumber,
                                   installmentGroupID: item.installmentGroupID))
        }
        for item in file.incomes {
            context.insert(IncomeSource(name: item.name, amount: item.amount))
        }
        for item in file.incomeSnapshots {
            context.insert(IncomeSnapshot(monthStart: item.monthStart, total: item.total))
        }
        for item in file.payments {
            context.insert(FixedPayment(name: item.name, amount: item.amount,
                                        dueDay: item.dueDay, category: item.category,
                                        totalInstallments: item.totalInstallments,
                                        firstPaymentDate: item.firstPaymentDate))
        }
        for item in file.paidPayments {
            context.insert(PaidPayment(paymentName: item.paymentName,
                                       monthStart: item.monthStart, paidAt: item.paidAt))
        }
        for item in file.paymentMonthAmounts {
            context.insert(PaymentMonthAmount(paymentName: item.paymentName,
                                              monthStart: item.monthStart,
                                              amount: item.amount))
        }
        for item in file.accounts {
            let account = SavingsAccountModel(name: item.name, kind: item.kind)
            account.createdAt = item.createdAt
            context.insert(account)
            for assetItem in item.assets {
                let asset = Asset(accountKind: assetItem.accountKind, name: assetItem.name,
                                  code: assetItem.code, unitPrice: assetItem.unitPrice,
                                  account: account)
                asset.priceUpdatedAt = assetItem.priceUpdatedAt
                context.insert(asset)
                for txItem in assetItem.transactions {
                    context.insert(AssetTransaction(date: txItem.date,
                                                    quantity: txItem.quantity,
                                                    pricePerUnit: txItem.pricePerUnit,
                                                    interestRate: txItem.interestRate,
                                                    asset: asset))
                }
            }
        }
        for item in file.savingsSnapshots {
            context.insert(SavingsSnapshot(monthStart: item.monthStart, total: item.total))
        }
        for item in file.debts {
            context.insert(Debt(name: item.name, kind: item.kind, quantity: item.quantity,
                                date: item.date, lastKnownRate: item.lastKnownRate,
                                initialRate: item.initialRate))
        }
        for item in file.expenseCategories {
            context.insert(CustomCategory(name: item.name, icon: item.icon,
                                          colorName: item.colorName,
                                          createdAt: item.createdAt))
        }
        for item in file.paymentCategories {
            context.insert(CustomPaymentCategory(name: item.name, icon: item.icon,
                                                 colorName: item.colorName,
                                                 amountVaries: item.amountVaries,
                                                 createdAt: item.createdAt))
        }
        try context.save()

        // 3) Ayarlar — avatar bu kullanıcıya bağlanır
        let defaults = UserDefaults.standard
        if let avatarID = file.settings.avatarID {
            defaults.set(avatarID, forKey: avatarStorageKey(for: user))
        }
        if let theme = file.settings.appTheme { defaults.set(theme, forKey: "appTheme") }
        if let language = file.settings.appLanguage {
            defaults.set(language, forKey: "appLanguage")
        }
        if let hidden = file.settings.hideIncomeAmounts {
            defaults.set(hidden, forKey: "hideIncomeAmounts")
        }
        if let model = file.settings.aiModelName { defaults.set(model, forKey: "aiModelName") }

        // 4) Kendi kategorileri ve ödeme hatırlatmaları yeniden kurulur
        ExpenseCategory.refreshCustom(context)
        PaymentCategory.refreshCustom(context)
        let payments = (try? context.fetch(FetchDescriptor<FixedPayment>())) ?? []
        let paid = (try? context.fetch(FetchDescriptor<PaidPayment>())) ?? []
        let amounts = (try? context.fetch(FetchDescriptor<PaymentMonthAmount>())) ?? []
        PaymentReminders.reschedule(payments: payments, paidRecords: paid,
                                    monthlyAmounts: amounts)
    }
}

// MARK: - Ayarlar > Yedekleme

struct BackupSettingsView: View {
    let user: String
    @Environment(\.modelContext) private var modelContext

    @State private var exportURL: URL?
    @State private var exportedAt = Date.now
    @State private var showingImporter = false
    @State private var pendingFile: BackupFile?
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        List {
            Section {
                Button {
                    exportBackup()
                } label: {
                    Label(tr("Yedek Oluştur", "Create Backup"),
                          systemImage: "square.and.arrow.up")
                }
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label(tr("Yedeği Paylaş / Kaydet", "Share / Save Backup"),
                              systemImage: "folder.badge.plus")
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exportURL.lastPathComponent)
                        // Dosya adında tarih olmadığı için yedeğin anı burada yazıyor
                        Text(tr("Alındı: ", "Taken: ") + readableDate(exportedAt))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text(tr("Yedek Al", "Back Up"))
            } footer: {
                Text(tr("""
                Tüm harcamaların, sabit ödemelerin, gelirlerin, birikimlerin, borçların, \
                kendi kategorilerin, ödedim işaretlerin ve avatarın tek bir dosyaya yazılır. \
                Dosya adı hep aynıdır; Dosyalar'a kaydederken "Değiştir" dersen tek bir \
                yedeğin olur ve her seferinde tazelenir. Uygulamayı silsen bile bu dosyadan \
                geri dönebilirsin.
                """, """
                All your expenses, fixed payments, income, savings, debts, custom categories, \
                paid marks and avatar are written to a single file. Save it to Files or send it \
                to yourself; you can restore from it even if the app is deleted.
                """))
            }

            Section {
                Button(role: .destructive) {
                    showingImporter = true
                } label: {
                    Label(tr("Yedekten Geri Yükle", "Restore From Backup"),
                          systemImage: "square.and.arrow.down")
                }
            } header: {
                Text(tr("Geri Yükle", "Restore"))
            } footer: {
                Text(tr("""
                Geri yükleme, "\(user)" hesabındaki mevcut verilerin tamamını siler ve yerine \
                yedektekileri yazar. Yeni açtığın bir hesaba başka bir hesabın yedeğini de \
                yükleyebilirsin. Onay sormadan hiçbir şey değişmez.
                """, """
                Restoring deletes everything currently in the "\(user)" account and replaces it \
                with the backup. You can also load another account's backup into a new account. \
                Nothing changes without your confirmation.
                """))
            }

            Section {
                Label(tr("Giriş şifren ve yapay zeka anahtarın yedeğe konmaz",
                         "Your password and AI key are not included"),
                      systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } footer: {
                Text(tr("""
                Bunlar kimlik bilgisi olduğu için, paylaşılabilecek bir dosyaya yazılmıyor. \
                Geri yükledikten sonra yapay zeka anahtarını Ayarlar > Yapay Zeka'dan tekrar girmen yeterli.
                """, """
                These are credentials, so they are never written to a file you might share. \
                After restoring, just re-enter the AI key from Settings > AI.
                """))
            }
        }
        .navigationTitle(tr("Yedekleme", "Backup"))
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            handlePicked(result)
        }
        .alert(tr("Geri yüklensin mi?", "Restore?"), isPresented: pendingBinding) {
            Button(tr("Vazgeç", "Cancel"), role: .cancel) { pendingFile = nil }
            Button(tr("Geri Yükle", "Restore"), role: .destructive) { performRestore() }
        } message: {
            if let pendingFile {
                Text(confirmationText(for: pendingFile))
            }
        }
        .alert(isError ? tr("Olmadı", "Failed") : tr("Tamam", "Done"),
               isPresented: messageBinding) {
            Button("Tamam") { message = nil }
        } message: {
            if let message { Text(message) }
        }
    }

    // Tarih cihazın değil, uygulamanın seçili diliyle yazılır
    private func readableDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year()
            .hour().minute().locale(appLocale))
    }

    private var pendingBinding: Binding<Bool> {
        Binding(get: { pendingFile != nil }, set: { if !$0 { pendingFile = nil } })
    }

    private var messageBinding: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }

    private func confirmationText(for file: BackupFile) -> String {
        let info = BackupService.contents(of: file)
        let date = readableDate(info.createdAt)
        let counts = tr("""
        \(info.expenses) harcama, \(info.payments) sabit ödeme, \(info.incomes) gelir, \
        \(info.accounts) birikim hesabı, \(info.debts) borç, \(info.categories) kendi kategorin.
        """, """
        \(info.expenses) expenses, \(info.payments) fixed payments, \(info.incomes) income \
        sources, \(info.accounts) savings accounts, \(info.debts) debts, \
        \(info.categories) custom categories.
        """)
        return tr("""
        Yedek: "\(info.user)" hesabı, \(date).
        İçinde: \(counts)

        "\(user)" hesabındaki mevcut tüm veriler silinip bunlar yazılacak. Bu işlem geri alınamaz.
        """, """
        Backup: "\(info.user)" account, \(date).
        Contains: \(counts)

        Everything currently in "\(user)" will be deleted and replaced. This cannot be undone.
        """)
    }

    private func exportBackup() {
        do {
            exportURL = try BackupService.exportToFile(modelContext, user: user)
            exportedAt = .now
        } catch {
            isError = true
            message = error.localizedDescription
        }
    }

    private func handlePicked(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let file = try BackupService.read(url)
            guard !BackupService.contents(of: file).isEmpty else {
                isError = true
                message = tr("Bu yedek boş görünüyor, geri yüklenecek bir şey yok.",
                             "This backup looks empty; there is nothing to restore.")
                return
            }
            pendingFile = file
        } catch {
            isError = true
            message = error.localizedDescription
        }
    }

    private func performRestore() {
        guard let file = pendingFile else { return }
        pendingFile = nil
        do {
            try BackupService.restore(file, into: modelContext, user: user)
            let info = BackupService.contents(of: file)
            isError = false
            message = tr("""
            Geri yüklendi: \(info.expenses) harcama, \(info.payments) sabit ödeme, \
            \(info.accounts) birikim hesabı ve diğer her şey yerine kondu.
            """, """
            Restored: \(info.expenses) expenses, \(info.payments) fixed payments, \
            \(info.accounts) savings accounts and everything else is back in place.
            """)
        } catch {
            isError = true
            message = error.localizedDescription
        }
    }
}
