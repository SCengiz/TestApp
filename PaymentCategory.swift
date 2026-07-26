import SwiftUI
import SwiftData

// Sabit ödeme kategorileri: ad + ikon + renk + tutarın her ay değişip değişmediği.
//
// amountVaries: kredi kartı ekstresi ve fatura gibi tutarı her ay belli olmayan
// ödemeler. Gelecek ayların planında bunlar 0 TL gösterilir — ekstre henüz
// kesilmediği için tutar bilinmez. Kira/kredi taksidi gibi sabit tutarlılar
// gelecek aylarda da kendi tutarlarıyla görünür.
struct PaymentCategory: Identifiable, Hashable {
    let name: String
    let icon: String
    let color: Color
    let amountVaries: Bool
    var isCustom: Bool = false
    var id: String { name }

    // Uygulamayla gelen hazır kategoriler
    static let builtIn: [PaymentCategory] = [
        .init(name: "Kredi Kartı", icon: "creditcard.fill", color: .blue, amountVaries: true),
        .init(name: "Kredi", icon: "banknote.fill", color: .indigo, amountVaries: false),
        .init(name: "Kira", icon: "house.fill", color: .orange, amountVaries: false),
        .init(name: "Fatura", icon: "doc.text.fill", color: .purple, amountVaries: true),
        .init(name: "Abonelik", icon: "tv.fill", color: .cyan, amountVaries: false),
        .init(name: "Sigorta", icon: "shield.lefthalf.filled", color: .green, amountVaries: false),
        .init(name: "Aidat", icon: "building.2.fill", color: .brown, amountVaries: false),
    ]

    static let other = PaymentCategory(name: "Diğer", icon: "ellipsis.circle.fill",
                                       color: .gray, amountVaries: false)

    // Kullanıcının Ayarlar'dan eklediği kategoriler (veritabanından tazelenir)
    private(set) static var custom: [PaymentCategory] = []

    static func refreshCustom(_ context: ModelContext) {
        let descriptor = FetchDescriptor<CustomPaymentCategory>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let saved = (try? context.fetch(descriptor)) ?? []
        custom = saved.map(PaymentCategory.init(model:))
    }

    init(model: CustomPaymentCategory) {
        self.name = model.name
        self.icon = model.icon
        self.color = categoryColor(named: model.colorName)
        self.amountVaries = model.amountVaries
        self.isCustom = true
    }

    private init(name: String, icon: String, color: Color,
                 amountVaries: Bool, isCustom: Bool = false) {
        self.name = name
        self.icon = icon
        self.color = color
        self.amountVaries = amountVaries
        self.isCustom = isCustom
    }

    static var all: [PaymentCategory] {
        builtIn + custom + [other]
    }

    // İngilizce modda ekranda gösterilen ad (kayıtlardaki ad Türkçe kalır)
    var displayName: String {
        guard isEnglishUI else { return name }
        switch name {
        case "Kredi Kartı": return "Credit Card"
        case "Kredi":       return "Loan"
        case "Kira":        return "Rent"
        case "Fatura":      return "Bill"
        case "Abonelik":    return "Subscription"
        case "Sigorta":     return "Insurance"
        case "Aidat":       return "Dues"
        case "Diğer":       return "Other"
        default:            return name
        }
    }

    // İsimden kategori bul; bulunamazsa "Diğer"
    static func named(_ name: String) -> PaymentCategory {
        all.first { $0.name == name } ?? other
    }
}

// Kullanıcının Ayarlar'dan eklediği sabit ödeme kategorisi
@Model
final class CustomPaymentCategory {
    var name: String = ""
    var icon: String = "creditcard.fill"
    var colorName: String = "mavi"
    var amountVaries: Bool = false
    var createdAt: Date = Date.now

    init(name: String, icon: String, colorName: String,
         amountVaries: Bool, createdAt: Date = .now) {
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.amountVaries = amountVaries
        self.createdAt = createdAt
    }
}

// Ödeme kategorisi eklerken seçilebilen simgeler
let paymentIconOptions: [String] = [
    "creditcard.fill", "banknote.fill", "house.fill", "doc.text.fill",
    "tv.fill", "shield.lefthalf.filled", "building.2.fill", "car.fill",
    "phone.fill", "wifi", "bolt.fill", "flame.fill",
    "drop.fill", "graduationcap.fill", "heart.fill", "figure.run",
    "pawprint.fill", "airplane", "wrench.and.screwdriver.fill", "briefcase.fill",
]

// MARK: - Ayarlar > Ödeme Kategorileri

struct PaymentCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomPaymentCategory.createdAt) private var customCategories: [CustomPaymentCategory]
    @State private var showingAddSheet = false
    @State private var editingCategory: CustomPaymentCategory?

    var body: some View {
        List {
            Section {
                if customCategories.isEmpty {
                    Text(tr("Henüz kendi kategorin yok.", "You have no categories of your own yet."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customCategories) { category in
                        Button {
                            editingCategory = category
                        } label: {
                            HStack(spacing: 12) {
                                RowIcon(systemName: category.icon,
                                        color: categoryColor(named: category.colorName))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                        .foregroundStyle(.primary)
                                    if category.amountVaries {
                                        Text(tr("Tutarı her ay değişir", "Amount changes monthly"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteCategories)
                }
            } header: {
                Text(tr("Kendi Kategorilerim", "My Categories"))
            } footer: {
                Text(tr("Sağ üstteki + ile ekle. Bir kategoriyi silersen o kategorideki ödemelerin silinmez, \"Diğer\" altında görünür.", "Add with + at the top right. If you delete a category, payments are not deleted; they show under \"Other\"."))
            }

            Section {
                ForEach(PaymentCategory.builtIn + [PaymentCategory.other]) { category in
                    HStack(spacing: 12) {
                        RowIcon(systemName: category.icon, color: category.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.displayName)
                            if category.amountVaries {
                                Text(tr("Tutarı her ay değişir", "Amount changes monthly"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(tr("Hazır Kategoriler", "Built-in Categories"))
            } footer: {
                Text(tr("\"Tutarı her ay değişir\" işaretli kategoriler (kredi kartı ekstresi, fatura) gelecek ayların planında 0 TL görünür; tutar belli olunca ödemeyi güncellersin.", "Categories marked \"amount changes monthly\" (card statements, bills) show ₺0 in future months until you enter the amount."))
            }
        }
        .navigationTitle(tr("Ödeme Kategorileri", "Payment Categories"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showingAddSheet = true
            } label: {
                Label(tr("Kategori Ekle", "Add Category"), systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            PaymentCategoryFormView(category: nil)
        }
        .sheet(item: $editingCategory) { category in
            PaymentCategoryFormView(category: category)
        }
        .onAppear {
            PaymentCategory.refreshCustom(modelContext)
        }
        .onChange(of: customCategories.count) {
            PaymentCategory.refreshCustom(modelContext)
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(customCategories[index])
        }
        PaymentCategory.refreshCustom(modelContext)
    }
}

// Ödeme kategorisi ekleme / düzenleme formu (category nil ise yeni kayıt)
struct PaymentCategoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var customCategories: [CustomPaymentCategory]

    let category: CustomPaymentCategory?

    @State private var name = ""
    @State private var icon = "creditcard.fill"
    @State private var colorName = "mavi"
    @State private var amountVaries = false

    private let iconColumns = [GridItem(.adaptive(minimum: 52), spacing: 12)]

    private var isNameTaken: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let builtInNames = (PaymentCategory.builtIn + [PaymentCategory.other]).map(\.name)
        if builtInNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return true
        }
        return customCategories.contains {
            $0.persistentModelID != category?.persistentModelID
                && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("Kategori adı (örn. Okul Taksidi)", "Category name (e.g. Tuition)"),
                              text: $name)
                        .textInputAutocapitalization(.words)
                } footer: {
                    if isNameTaken {
                        Text(tr("Bu adda bir kategori zaten var.", "A category with this name already exists."))
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Toggle(tr("Tutarı her ay değişir", "Amount changes monthly"), isOn: $amountVaries)
                } footer: {
                    Text(tr("Kredi kartı ekstresi ve fatura gibi tutarı önceden bilinmeyen ödemeler için aç. Gelecek ayların planında 0 TL görünür; tutar belli olunca ödemeyi güncellersin.", "Turn on for payments whose amount isn't known in advance, like card statements and bills. Future months show ₺0 until you enter the amount."))
                }

                Section(tr("Renk", "Color")) {
                    Picker(tr("Renk", "Color"), selection: $colorName) {
                        ForEach(categoryColorOptions, id: \.name) { option in
                            Text(tr(option.turkish, option.english)).tag(option.name)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(tr("Simge", "Icon")) {
                    LazyVGrid(columns: iconColumns, spacing: 12) {
                        ForEach(paymentIconOptions, id: \.self) { option in
                            Button {
                                icon = option
                            } label: {
                                Image(systemName: option)
                                    .font(.title3)
                                    .foregroundStyle(icon == option ? .white : Color.primary)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(icon == option
                                                  ? categoryColor(named: colorName)
                                                  : Color.gray.opacity(0.15))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if category != nil {
                    Section {
                        Button(tr("Kategoriyi Sil", "Delete Category"), role: .destructive) {
                            deleteCategory()
                        }
                        .frame(maxWidth: .infinity)
                    } footer: {
                        Text(tr("Ödemelerin silinmez; \"Diğer\" altında görünür.", "Payments are not deleted; they show under \"Other\"."))
                    }
                }
            }
            .navigationTitle(category == nil
                             ? tr("Kategori Ekle", "Add Category")
                             : tr("Kategoriyi Düzenle", "Edit Category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Vazgeç", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Kaydet", "Save")) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isNameTaken)
                }
            }
            .onAppear {
                if let category {
                    name = category.name
                    icon = category.icon
                    colorName = category.colorName
                    amountVaries = category.amountVaries
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let category {
            // Ad değişirse o kategorideki ödemeler de yeni adı görsün
            let oldName = category.name
            category.name = trimmed
            category.icon = icon
            category.colorName = colorName
            category.amountVaries = amountVaries
            if oldName != trimmed {
                renamePayments(from: oldName, to: trimmed)
            }
        } else {
            modelContext.insert(CustomPaymentCategory(name: trimmed, icon: icon,
                                                      colorName: colorName,
                                                      amountVaries: amountVaries))
        }
        try? modelContext.save()
        PaymentCategory.refreshCustom(modelContext)
        dismiss()
    }

    private func renamePayments(from oldName: String, to newName: String) {
        let descriptor = FetchDescriptor<FixedPayment>(
            predicate: #Predicate { $0.category == oldName }
        )
        let affected = (try? modelContext.fetch(descriptor)) ?? []
        for payment in affected {
            payment.category = newName
        }
    }

    private func deleteCategory() {
        if let category {
            modelContext.delete(category)
            try? modelContext.save()
            PaymentCategory.refreshCustom(modelContext)
        }
        dismiss()
    }
}
