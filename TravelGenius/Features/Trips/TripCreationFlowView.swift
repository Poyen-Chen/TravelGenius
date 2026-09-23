import SwiftUI
import SwiftData

struct TripCreationFlowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme
    @Environment(AppState.self) private var appState

    @State private var search = ""
    @State private var selectedCityIDs: Set<String> = ["JP-京都", "JP-大阪"]
    @State private var startDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var selectedTags: Set<String> = ["美食", "購物"]

    private let suggestedCityNames = ["京都", "大阪", "首爾"]
    private let tags = ["泡溫泉", "美食", "賞雪", "購物"]

    private var allSuggestedCities: [City] {
        suggestedCityNames.compactMap { name in StaticDataStore.shared.cities.first { $0.cityZh == name } }
    }

    private var filteredCities: [City] {
        guard !search.trimmingCharacters(in: .whitespaces).isEmpty else { return allSuggestedCities }
        return StaticDataStore.shared.cities.filter { $0.cityZh.localizedCaseInsensitiveContains(search) }
    }

    private var selectedCities: [City] {
        StaticDataStore.shared.cities.filter { selectedCityIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.large) {
                    destinationSection
                    dateSection
                    natureSection
                    MascotBubbleRow(message: "選好目的地與日期後，我會沿用規則引擎，先幫你生成一份可調整的清單。")
                    Button("建立並生成清單", action: createTrip)
                        .buttonStyle(PackmonPrimaryButtonStyle())
                }
                .padding(theme.spacing.medium)
                .padding(.bottom, 24)
            }
            .background(theme.colors.canvas.ignoresSafeArea())
            .navigationTitle("新行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("我的行程", systemImage: "chevron.left") }
                }
            }
            .onChange(of: startDate) { _, value in if endDate < value { endDate = value } }
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("想去哪裡？", subtitle: "可以選一個或多個城市")
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.colors.secondaryText)
                TextField("搜尋城市或國家", text: $search)
            }
            .padding(.horizontal, 14).frame(height: 50)
            .background(theme.colors.elevatedSurface, in: RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: theme.radius.medium).stroke(theme.colors.separator, lineWidth: 0.75) }
            HStack(spacing: 9) {
                ForEach(filteredCities.prefix(3)) { city in
                    selectionChip(city.cityZh, isSelected: selectedCityIDs.contains(city.id)) {
                        if selectedCityIDs.contains(city.id) { selectedCityIDs.remove(city.id) } else { selectedCityIDs.insert(city.id) }
                    }
                }
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("什麼時候出發？", subtitle: "共 \(tripDays) 天")
            PackmonCard {
                VStack(spacing: 12) {
                    DatePicker("出發", selection: $startDate, displayedComponents: .date)
                    Divider().overlay(theme.colors.separator)
                    DatePicker("回程", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
        }
    }

    private var natureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("這趟想做什麼？", subtitle: "可複選，之後能再調整")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(tags, id: \.self) { tag in
                    selectionChip(tag, isSelected: selectedTags.contains(tag)) {
                        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.weight(.black)).foregroundStyle(theme.colors.text)
            Text(subtitle).font(.caption).foregroundStyle(theme.colors.secondaryText)
        }
    }

    private func selectionChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected { Image(systemName: "checkmark") }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : theme.colors.text)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(isSelected ? theme.colors.accent : theme.colors.elevatedSurface, in: Capsule())
            .overlay { if !isSelected { Capsule().stroke(theme.colors.separator, lineWidth: 0.75) } }
        }.buttonStyle(.plain)
    }

    private var tripDays: Int {
        max((Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: endDate)).day ?? 0) + 1, 1)
    }

    private func createTrip() {
        guard let primary = selectedCities.first ?? allSuggestedCities.first else { return }
        let names = selectedCities.map(\.cityZh)
        let country = StaticDataStore.shared.country(code: primary.countryCode)
        let trip = Trip(
            name: names.isEmpty ? primary.cityZh : names.joined(separator: "・"),
            countryCode: primary.countryCode,
            startDate: startDate,
            endDate: endDate,
            homeCurrencyCode: "TWD",
            localCurrencyCode: country?.currencyCode ?? "TWD",
            totalBudget: 0,
            tripType: .leisure
        )
        trip.city = primary.cityZh
        trip.originCountryCode = "TW"
        trip.originCity = "台北"
        trip.hasReviewedTravelRules = false
        context.insert(trip)
        PackingListGenerator.sync(trip: trip, context: context)
        appState.setActive(trip)
        WidgetSync.update(trip: trip)
        try? context.save()
        dismiss()
    }
}
