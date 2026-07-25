import SwiftUI

// Profil avatarı: kayıt olurken seçilir, Ayarlar'dan değiştirilebilir.
// Kullanıcıya özel olarak UserDefaults'ta saklanır (şifre gibi).
struct ProfileAvatar: Identifiable, Hashable {
    let id: String
    let emoji: String
    let colors: [Color]

    var turkishName: String
    var englishName: String

    var name: String { tr(turkishName, englishName) }
}

let profileAvatars: [ProfileAvatar] = [
    .init(id: "cat", emoji: "🐱",
          colors: [Color(red: 1.00, green: 0.85, blue: 0.45), Color(red: 0.97, green: 0.62, blue: 0.25)],
          turkishName: "Kedi", englishName: "Cat"),
    .init(id: "dog", emoji: "🐶",
          colors: [Color(red: 0.72, green: 0.88, blue: 1.00), Color(red: 0.36, green: 0.60, blue: 0.95)],
          turkishName: "Köpek", englishName: "Dog"),
    .init(id: "fox", emoji: "🦊",
          colors: [Color(red: 1.00, green: 0.76, blue: 0.52), Color(red: 0.94, green: 0.46, blue: 0.20)],
          turkishName: "Tilki", englishName: "Fox"),
    .init(id: "panda", emoji: "🐼",
          colors: [Color(red: 0.92, green: 0.94, blue: 0.97), Color(red: 0.62, green: 0.67, blue: 0.75)],
          turkishName: "Panda", englishName: "Panda"),
    .init(id: "bear", emoji: "🐻",
          colors: [Color(red: 0.86, green: 0.72, blue: 0.58), Color(red: 0.60, green: 0.42, blue: 0.28)],
          turkishName: "Ayı", englishName: "Bear"),
    .init(id: "tiger", emoji: "🐯",
          colors: [Color(red: 1.00, green: 0.82, blue: 0.35), Color(red: 0.95, green: 0.55, blue: 0.12)],
          turkishName: "Kaplan", englishName: "Tiger"),
    .init(id: "koala", emoji: "🐨",
          colors: [Color(red: 0.85, green: 0.88, blue: 0.92), Color(red: 0.55, green: 0.62, blue: 0.70)],
          turkishName: "Koala", englishName: "Koala"),
    .init(id: "rabbit", emoji: "🐰",
          colors: [Color(red: 1.00, green: 0.85, blue: 0.92), Color(red: 0.92, green: 0.58, blue: 0.75)],
          turkishName: "Tavşan", englishName: "Rabbit"),
    .init(id: "mouse", emoji: "🐭",
          colors: [Color(red: 0.90, green: 0.88, blue: 0.96), Color(red: 0.62, green: 0.58, blue: 0.85)],
          turkishName: "Fare", englishName: "Mouse"),
    .init(id: "owl", emoji: "🦉",
          colors: [Color(red: 0.88, green: 0.80, blue: 0.66), Color(red: 0.58, green: 0.45, blue: 0.32)],
          turkishName: "Baykuş", englishName: "Owl"),
    .init(id: "giraffe", emoji: "🦒",
          colors: [Color(red: 1.00, green: 0.84, blue: 0.52), Color(red: 0.85, green: 0.58, blue: 0.22)],
          turkishName: "Zürafa", englishName: "Giraffe"),
    .init(id: "shark", emoji: "🦈",
          colors: [Color(red: 0.68, green: 0.86, blue: 0.95), Color(red: 0.24, green: 0.55, blue: 0.78)],
          turkishName: "Köpekbalığı", englishName: "Shark"),
    .init(id: "chicken", emoji: "🐔",
          colors: [Color(red: 1.00, green: 0.88, blue: 0.62), Color(red: 0.94, green: 0.48, blue: 0.35)],
          turkishName: "Tavuk", englishName: "Chicken"),
    .init(id: "unicorn", emoji: "🦄",
          colors: [Color(red: 0.95, green: 0.78, blue: 1.00), Color(red: 0.62, green: 0.42, blue: 0.92)],
          turkishName: "Tek Boynuzlu", englishName: "Unicorn"),
    .init(id: "alien", emoji: "👽",
          colors: [Color(red: 0.72, green: 0.92, blue: 0.85), Color(red: 0.30, green: 0.68, blue: 0.62)],
          turkishName: "Uzaylı", englishName: "Alien"),
    .init(id: "skull", emoji: "💀",
          colors: [Color(red: 0.82, green: 0.84, blue: 0.88), Color(red: 0.42, green: 0.46, blue: 0.54)],
          turkishName: "Kurukafa", englishName: "Skull"),
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
                .strokeBorder(.white.opacity(0.45), lineWidth: max(1, size * 0.02))

            Text(avatar.emoji)
                .font(.system(size: size * 0.58))
                .shadow(color: .black.opacity(0.18), radius: size * 0.025, y: size * 0.015)
        }
        .frame(width: size, height: size)
        .shadow(color: (avatar.colors.last ?? .black).opacity(0.35),
                radius: size * 0.09, y: size * 0.04)
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
                VStack(spacing: 14) {
                    AvatarView(avatar: avatar(withID: selectedID), size: 72)
                        .padding(.top, 4)

                    Text(avatar(withID: selectedID).name)
                        .font(.headline)

                    AvatarPicker(selectedID: $selectedID, size: 52, showsNames: false)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
        // Yarım ekran açılır; istenirse yukarı çekip büyütülebilir
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
