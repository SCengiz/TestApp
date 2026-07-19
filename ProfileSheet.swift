import SwiftUI
import SwiftData

// Sol üstteki kullanıcı simgesi: dokununca profil/ayarlar penceresi açılır
struct ProfileButton: View {
    @Binding var loggedInUser: String?
    @State private var showingSheet = false

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
        }
        .sheet(isPresented: $showingSheet) {
            ProfileSheet(loggedInUser: $loggedInUser)
        }
    }
}

// Profil penceresi: ad, ayarlar ve çıkış
struct ProfileSheet: View {
    @Binding var loggedInUser: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingResetConfirm = false

    private var displayName: String {
        (loggedInUser ?? "").capitalized
    }

    var body: some View {
        NavigationStack {
            List {
                // En üstte kullanıcı adı
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                        Text(displayName)
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Ayarlar
                Section("Ayarlar") {
                    HStack {
                        Label("Uygulama Sürümü", systemImage: "info.circle")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingResetConfirm = true
                    } label: {
                        Label("Örnek Verileri Sıfırla", systemImage: "arrow.counterclockwise")
                    }
                }

                // Çıkış
                Section {
                    Button("Çıkış Yap", role: .destructive) {
                        loggedInUser = nil
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .confirmationDialog("Tüm veriler silinip örnek verilerle yeniden başlatılacak. Emin misin?",
                                isPresented: $showingResetConfirm,
                                titleVisibility: .visible) {
                Button("Sıfırla", role: .destructive) {
                    resetAllData()
                    dismiss()
                }
                Button("Vazgeç", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
    }

    // Tüm verileri silip örnek verileri yeniden yükle
    private func resetAllData() {
        try? modelContext.delete(model: Expense.self)
        try? modelContext.delete(model: FixedPayment.self)
        try? modelContext.delete(model: IncomeSource.self)
        try? modelContext.delete(model: IncomeSnapshot.self)
        try? modelContext.delete(model: AssetTransaction.self)
        try? modelContext.delete(model: Asset.self)
        try? modelContext.delete(model: SavingsAccountModel.self)
        try? modelContext.delete(model: SavingsSnapshot.self)
        try? modelContext.delete(model: Debt.self)
        try? modelContext.save()
        seedSampleDataIfNeeded(modelContext)
    }
}

#Preview {
    ProfileSheet(loggedInUser: .constant("soray"))
}
