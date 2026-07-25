import SwiftUI
import SwiftData

// Uygulama teması (Ayarlar'dan seçilir, tüm uygulamaya uygulanır)
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return tr("Sistem", "System")
        case .light:  return tr("Açık", "Light")
        case .dark:   return tr("Koyu", "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// Sol üstteki kullanıcı simgesi: dokununca profil penceresi açılır
struct ProfileButton: View {
    @Binding var loggedInUser: String?
    @AppStorage private var avatarID: String
    @State private var showingSheet = false

    init(loggedInUser: Binding<String?>) {
        self._loggedInUser = loggedInUser
        let user = loggedInUser.wrappedValue ?? ""
        // Avatar değişince buton kendiliğinden güncellensin
        self._avatarID = AppStorage(wrappedValue: defaultAvatarID,
                                    avatarStorageKey(for: user))
    }

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            AvatarView(avatar: avatar(withID: avatarID), size: 30)
        }
        .sheet(isPresented: $showingSheet) {
            ProfileSheet(loggedInUser: $loggedInUser)
        }
    }
}

// Profil penceresi: ad, ayarlar ve çıkış
struct ProfileSheet: View {
    @Binding var loggedInUser: String?
    @AppStorage private var avatarID: String
    @State private var showingAvatarSheet = false

    @Environment(\.dismiss) private var dismiss

    init(loggedInUser: Binding<String?>) {
        self._loggedInUser = loggedInUser
        let user = loggedInUser.wrappedValue ?? ""
        self._avatarID = AppStorage(wrappedValue: defaultAvatarID,
                                    avatarStorageKey(for: user))
    }

    private var displayName: String {
        (loggedInUser ?? "").capitalized
    }

    var body: some View {
        NavigationStack {
            List {
                // En üstte kullanıcı adı
                Section {
                    VStack(spacing: 10) {
                        // Avatara dokununca değiştirme ekranı açılır
                        Button {
                            showingAvatarSheet = true
                        } label: {
                            AvatarView(avatar: avatar(withID: avatarID), size: 88)
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.white, Color.accentColor)
                                }
                        }
                        .buttonStyle(.plain)

                        Text(displayName)
                            .font(.title2.bold())
                        Text(tr("Avatarı değiştirmek için dokun", "Tap to change your avatar"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Ayarlar ekranına giriş
                Section {
                    NavigationLink {
                        SettingsView(user: loggedInUser ?? "")
                    } label: {
                        Label(tr("Ayarlar", "Settings"), systemImage: "gearshape.fill")
                    }
                }

                // Çıkış
                Section {
                    Button(tr("Çıkış Yap", "Log Out"), role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "rememberedUser")
                        loggedInUser = nil
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(tr("Profil", "Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Kapat", "Close")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingAvatarSheet) {
                AvatarEditSheet(user: loggedInUser ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// Ayarlar ekranı (yeni ayarlar buraya eklenecek)
struct SettingsView: View {
    let user: String
    @AppStorage("appTheme") private var themeRaw = AppTheme.system.rawValue
    @AppStorage("appLanguage") private var appLanguage = "tr"

    var body: some View {
        List {
            Section {
                Picker(selection: $themeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                } label: {
                    Label(tr("Tema", "Theme"), systemImage: "circle.lefthalf.filled")
                }
                .pickerStyle(.menu)
                Picker(selection: $appLanguage) {
                    Text(tr("Türkçe", "Türkçe")).tag("tr")
                    Text(tr("English", "English")).tag("en")
                } label: {
                    Label(tr("Dil", "Language"), systemImage: "globe")
                }
                .pickerStyle(.menu)
            } header: {
                Text(tr("Görünüm", "Appearance"))
            } footer: {
                Text(tr("\"Sistem\" teması telefonun açık/koyu ayarına uyar. Dil seçimi tüm uygulama metinlerini değiştirir.", "\"System\" theme follows your phone. Language changes all app texts."))
            }

            Section {
                NavigationLink {
                    CategoriesView()
                } label: {
                    Label(tr("Kategoriler", "Categories"), systemImage: "square.grid.2x2.fill")
                }
            } footer: {
                Text(tr("Harcamalarına kendi kategorilerini ekleyebilirsin.", "You can add your own expense categories."))
            }

            Section(tr("Hesap", "Account")) {
                NavigationLink {
                    ChangePasswordView(user: user)
                } label: {
                    Label(tr("Şifre Değiştir", "Change Password"), systemImage: "key.fill")
                }
            }

            Section(tr("Hakkında", "About")) {
                HStack {
                    Label(tr("Uygulama Sürümü", "App Version"), systemImage: "info.circle")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(tr("Ayarlar", "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Kategoriler ekranı: hazır kategoriler + kullanıcının kendi eklediği kategoriler
struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]
    @State private var showingAddSheet = false
    @State private var editingCategory: CustomCategory?

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
                                Text(category.name)
                                    .foregroundStyle(.primary)
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
                Text(tr("Sağ üstteki + ile ekle. Bir kategoriyi silersen o kategoriyle kayıtlı eski harcamaların silinmez, \"Diğer\" altında görünür.", "Add with + at the top right. If you delete a category, past expenses are not deleted; they show under \"Other\"."))
            }

            Section {
                ForEach(ExpenseCategory.builtIn + [ExpenseCategory.other]) { category in
                    HStack(spacing: 12) {
                        RowIcon(systemName: category.icon, color: category.color)
                        Text(category.displayName)
                    }
                }
            } header: {
                Text(tr("Hazır Kategoriler", "Built-in Categories"))
            } footer: {
                Text(tr("Bunlar uygulamayla gelir; silinemez.", "These come with the app and cannot be deleted."))
            }
        }
        .navigationTitle(tr("Kategoriler", "Categories"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showingAddSheet = true
            } label: {
                Label(tr("Kategori Ekle", "Add Category"), systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CategoryFormView(category: nil)
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormView(category: category)
        }
        .onAppear {
            ExpenseCategory.refreshCustom(modelContext)
        }
        .onChange(of: customCategories.count) {
            ExpenseCategory.refreshCustom(modelContext)
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(customCategories[index])
        }
        ExpenseCategory.refreshCustom(modelContext)
    }
}

// Kategori ekleme / düzenleme formu (category nil ise yeni kayıt)
struct CategoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var customCategories: [CustomCategory]

    let category: CustomCategory?

    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var colorName = "mavi"

    private let iconColumns = [GridItem(.adaptive(minimum: 52), spacing: 12)]

    // Aynı ada sahip başka bir kategori var mı? (hazırlar dahil)
    private var isNameTaken: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let builtInNames = (ExpenseCategory.builtIn + [ExpenseCategory.other]).map(\.name)
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
                    TextField(tr("Kategori adı (örn. Kırtasiye)", "Category name (e.g. Stationery)"),
                              text: $name)
                        .textInputAutocapitalization(.words)
                } footer: {
                    if isNameTaken {
                        Text(tr("Bu adda bir kategori zaten var.", "A category with this name already exists."))
                            .foregroundStyle(.red)
                    } else {
                        Text(tr("Sesle harcama girerken bu adı söylersen kategori otomatik seçilir.", "If you say this name during voice entry, the category is picked automatically."))
                    }
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
                        ForEach(categoryIconOptions, id: \.self) { option in
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
                        Text(tr("Eski harcamaların silinmez; \"Diğer\" altında görünür.", "Past expenses are not deleted; they show under \"Other\"."))
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
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let category {
            // Ad değişirse eski harcamalar yeni adı görsün diye kayıtlar da güncellenir
            let oldName = category.name
            category.name = trimmed
            category.icon = icon
            category.colorName = colorName
            if oldName != trimmed {
                renameExpenses(from: oldName, to: trimmed)
            }
        } else {
            modelContext.insert(CustomCategory(name: trimmed, icon: icon, colorName: colorName))
        }
        try? modelContext.save()
        ExpenseCategory.refreshCustom(modelContext)
        dismiss()
    }

    private func renameExpenses(from oldName: String, to newName: String) {
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.category == oldName }
        )
        let affected = (try? modelContext.fetch(descriptor)) ?? []
        for expense in affected {
            expense.category = newName
        }
    }

    private func deleteCategory() {
        if let category {
            modelContext.delete(category)
            try? modelContext.save()
            ExpenseCategory.refreshCustom(modelContext)
        }
        dismiss()
    }
}

// Şifre değiştirme ekranı
struct ChangePasswordView: View {
    let user: String

    @Environment(\.dismiss) private var dismiss
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var newPasswordAgain = ""
    @State private var message: String?
    @State private var isSuccess = false

    var body: some View {
        Form {
            Section {
                SecureField(tr("Mevcut şifre", "Current password"), text: $oldPassword)
                SecureField(tr("Yeni şifre", "New password"), text: $newPassword)
                SecureField(tr("Yeni şifre (tekrar)", "New password (again)"), text: $newPasswordAgain)
            } footer: {
                if let message {
                    Text(message)
                        .foregroundStyle(isSuccess ? .green : .red)
                }
            }

            Section {
                Button(tr("Şifreyi Değiştir", "Change Password")) {
                    changePassword()
                }
                .frame(maxWidth: .infinity)
                .disabled(oldPassword.isEmpty || newPassword.isEmpty || newPasswordAgain.isEmpty)
            }
        }
        .navigationTitle(tr("Şifre Değiştir", "Change Password"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func changePassword() {
        isSuccess = false
        guard currentPassword(for: user) == oldPassword else {
            message = tr("Mevcut şifre hatalı.", "Current password is wrong.")
            return
        }
        guard newPassword == newPasswordAgain else {
            message = tr("Yeni şifreler birbiriyle uyuşmuyor.", "New passwords do not match.")
            return
        }
        guard newPassword != oldPassword else {
            message = tr("Yeni şifre eskisiyle aynı olamaz.", "New password cannot be the same as the old one.")
            return
        }
        setPassword(newPassword, for: user)
        isSuccess = true
        message = tr("Şifren değiştirildi. Bir sonraki girişte yeni şifreni kullan.", "Password changed. Use the new password next time you log in.")
        oldPassword = ""
        newPassword = ""
        newPasswordAgain = ""
    }
}

#Preview {
    ProfileSheet(loggedInUser: .constant("soray"))
}
