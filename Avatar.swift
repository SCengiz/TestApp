import SwiftUI

// Profil avatarı: kayıt olurken seçilir, Ayarlar'dan değiştirilebilir.
// Kullanıcıya özel olarak UserDefaults'ta saklanır (şifre gibi).
struct ProfileAvatar: Identifiable, Hashable {
    let id: String
    let symbol: String
    let colors: [Color]

    var turkishName: String
    var englishName: String

    var name: String { tr(turkishName, englishName) }
}

let profileAvatars: [ProfileAvatar] = [
    .init(id: "cat", symbol: "cat.fill",
          colors: [Color(red: 1.00, green: 0.68, blue: 0.30),
                   Color(red: 0.96, green: 0.42, blue: 0.24),
                   Color(red: 0.85, green: 0.24, blue: 0.35)],
          turkishName: "Kedi", englishName: "Cat"),
    .init(id: "dog", symbol: "dog.fill",
          colors: [Color(red: 0.55, green: 0.78, blue: 1.00),
                   Color(red: 0.28, green: 0.50, blue: 0.95),
                   Color(red: 0.18, green: 0.30, blue: 0.80)],
          turkishName: "Köpek", englishName: "Dog"),
    .init(id: "bird", symbol: "bird.fill",
          colors: [Color(red: 0.45, green: 0.95, blue: 0.80),
                   Color(red: 0.15, green: 0.75, blue: 0.68),
                   Color(red: 0.08, green: 0.52, blue: 0.55)],
          turkishName: "Kuş", englishName: "Bird"),
    .init(id: "night", symbol: "moon.stars.fill",
          colors: [Color(red: 0.42, green: 0.38, blue: 0.85),
                   Color(red: 0.26, green: 0.20, blue: 0.62),
                   Color(red: 0.12, green: 0.10, blue: 0.35)],
          turkishName: "Gece", englishName: "Night"),
    .init(id: "bolt", symbol: "bolt.fill",
          colors: [Color(red: 1.00, green: 0.86, blue: 0.30),
                   Color(red: 0.98, green: 0.66, blue: 0.10),
                   Color(red: 0.90, green: 0.45, blue: 0.05)],
          turkishName: "Şimşek", englishName: "Bolt"),
    .init(id: "leaf", symbol: "leaf.fill",
          colors: [Color(red: 0.65, green: 0.92, blue: 0.45),
                   Color(red: 0.33, green: 0.74, blue: 0.32),
                   Color(red: 0.15, green: 0.50, blue: 0.28)],
          turkishName: "Yaprak", englishName: "Leaf"),
    .init(id: "music", symbol: "music.note",
          colors: [Color(red: 1.00, green: 0.60, blue: 0.85),
                   Color(red: 0.88, green: 0.32, blue: 0.70),
                   Color(red: 0.60, green: 0.18, blue: 0.62)],
          turkishName: "Müzik", englishName: "Music"),
    .init(id: "flame", symbol: "flame.fill",
          colors: [Color(red: 1.00, green: 0.72, blue: 0.35),
                   Color(red: 0.95, green: 0.38, blue: 0.20),
                   Color(red: 0.75, green: 0.14, blue: 0.16)],
          turkishName: "Ateş", englishName: "Flame"),
    .init(id: "crown", symbol: "crown.fill",
          colors: [Color(red: 1.00, green: 0.90, blue: 0.55),
                   Color(red: 0.92, green: 0.72, blue: 0.22),
                   Color(red: 0.70, green: 0.48, blue: 0.08)],
          turkishName: "Taç", englishName: "Crown"),
    .init(id: "game", symbol: "gamecontroller.fill",
          colors: [Color(red: 0.72, green: 0.62, blue: 1.00),
                   Color(red: 0.45, green: 0.35, blue: 0.92),
                   Color(red: 0.26, green: 0.18, blue: 0.65)],
          turkishName: "Oyun", englishName: "Gaming"),
]

let defaultAvatarID = "cat"

func avatarStorageKey(for user: String) -> String {
    "avatar_\(user)"
}

func avatar(withID id: String) -> ProfileAvatar {
    profileAvatars.first { $0.id == id } ?? profileAvatars[0]
}

func avatar(for user: String) -> ProfileAvatar {
    let id = UserDefaults.standard.string(forKey: avatarStorageKey(for: user)) ?? defaultAvatarID
    return avatar(withID: id)
}

func setAvatar(_ id: String, for user: String) {
    UserDefaults.standard.set(id, forKey: avatarStorageKey(for: user))
}

// Renkli daire içinde avatar simgesi
struct AvatarView: View {
    let avatar: ProfileAvatar
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            // Renk geçişi
            Circle()
                .fill(
                    LinearGradient(colors: avatar.colors,
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
            // Sol üstten gelen ışık parlaması (hacim hissi verir)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.45), .clear],
                        center: UnitPoint(x: 0.3, y: 0.22),
                        startRadius: 0,
                        endRadius: size * 0.62
                    )
                )
            // İnce iç kenar
            Circle()
                .strokeBorder(.white.opacity(0.35), lineWidth: max(1, size * 0.02))

            Image(systemName: avatar.symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: size * 0.03, y: size * 0.02)
        }
        .frame(width: size, height: size)
        .shadow(color: (avatar.colors.last ?? .black).opacity(0.45),
                radius: size * 0.10, y: size * 0.05)
    }
}

// Yan yana avatar seçimi (kayıt ekranı ve avatar değiştirme ekranı)
struct AvatarPicker: View {
    @Binding var selectedID: String
    var size: CGFloat = 62
    var showsNames = true

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: size + 12), spacing: 12)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(profileAvatars) { item in
                Button {
                    selectedID = item.id
                } label: {
                    VStack(spacing: 6) {
                        AvatarView(avatar: item, size: size)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: selectedID == item.id ? 3 : 0)
                            )
                            .overlay(alignment: .bottomTrailing) {
                                if selectedID == item.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: size * 0.3))
                                        .foregroundStyle(.white, .green)
                                }
                            }
                            .scaleEffect(selectedID == item.id ? 1.0 : 0.88)
                            .opacity(selectedID == item.id ? 1 : 0.82)
                        if showsNames {
                            Text(item.name)
                                .font(.caption2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.snappy(duration: 0.2), value: selectedID)
    }
}

// Ayarlar/profil içinden avatar değiştirme ekranı
struct AvatarEditSheet: View {
    let user: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String

    init(user: String) {
        self.user = user
        _selectedID = State(initialValue: avatar(for: user).id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    AvatarView(avatar: avatar(withID: selectedID), size: 104)
                        .padding(.top, 12)

                    Text(avatar(withID: selectedID).name)
                        .font(.title3.bold())

                    AvatarPicker(selectedID: $selectedID, size: 58, showsNames: false)

                    Text(tr("Avatarını seç; profil simgende görünür.",
                            "Pick your avatar; it shows as your profile icon."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .navigationTitle(tr("Avatarı Değiştir", "Change Avatar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Vazgeç", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Kaydet", "Save")) {
                        setAvatar(selectedID, for: user)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}
