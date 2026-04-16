//
//  PackingListView.swift
//  StoneBC
//
//  Interactive bikepacking pack list adapted from bikepacking.com/bikepacking-101/pack-list/
//  Persistent checkmarks per trip. Categories: shelter, food, repair, clothing, electronics, safety.
//

import SwiftUI

// MARK: - Data Model

struct PackItem: Identifiable {
    let id: String
    let name: String
    let note: String?
    let isOptional: Bool

    init(_ name: String, note: String? = nil, optional: Bool = false) {
        self.id = name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.note = note
        self.isOptional = optional
    }
}

struct PackCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let subcategories: [(name: String, items: [PackItem])]

    var allItems: [PackItem] {
        subcategories.flatMap { $0.items }
    }
}

// MARK: - Pack List Data

enum BikepackingPackList {
    static let categories: [PackCategory] = [
        PackCategory(
            id: "shelter", name: "Shelter & Sleeping", icon: "tent", color: .blue,
            subcategories: [
                ("Shelter", [
                    PackItem("Tent or bivy", note: "Ultralight double-wall preferred"),
                    PackItem("Ground sheet"),
                    PackItem("Tarp", optional: true),
                    PackItem("Hammock with underquilt", optional: true),
                ]),
                ("Sleep System", [
                    PackItem("Sleeping bag or quilt", note: "30-40°F for Black Hills May nights"),
                    PackItem("Sleeping pad", note: "R-value 3+ for cold ground"),
                    PackItem("Sleeping bag liner", optional: true),
                    PackItem("Inflatable pillow", optional: true),
                ]),
            ]
        ),
        PackCategory(
            id: "food", name: "Food & Water", icon: "cup.and.saucer", color: .orange,
            subcategories: [
                ("Cooking", [
                    PackItem("Stove", note: "Isobutane canister or alcohol"),
                    PackItem("Fuel container"),
                    PackItem("Pot", note: "0.7-1.5L titanium"),
                    PackItem("Mug or cup"),
                    PackItem("Spork"),
                    PackItem("Lighter"),
                    PackItem("Bandana or small cloth"),
                    PackItem("Folding knife", optional: true),
                    PackItem("Coffee maker", optional: true),
                    PackItem("Salt, pepper, spices", note: "In pill bottles", optional: true),
                ]),
                ("Water", [
                    PackItem("Water bottles or bladder", note: "3L minimum for Black Hills gaps"),
                    PackItem("Bottle cages"),
                    PackItem("Water filter", note: "Sawyer Squeeze or tablets"),
                ]),
                ("Food — Day 1", [
                    PackItem("Lunch + dinner + snacks"),
                ]),
                ("Food — Day 2", [
                    PackItem("Breakfast + lunch + dinner", note: "Resupply in Custer Saturday AM"),
                ]),
                ("Food — Day 3", [
                    PackItem("Breakfast + lunch + snacks", note: "Resupply at Deerfield Sunday AM"),
                ]),
                ("Electrolytes & Extras", [
                    PackItem("Electrolyte mix"),
                    PackItem("Energy gels or bars"),
                ]),
            ]
        ),
        PackCategory(
            id: "repair", name: "Repair Kit & Spares", icon: "wrench.and.screwdriver", color: .red,
            subcategories: [
                ("Tools", [
                    PackItem("Multi-tool", note: "Allen + Torx bits"),
                    PackItem("Chain breaker"),
                    PackItem("Master link pliers"),
                    PackItem("Chain lube", note: "1oz bottle"),
                    PackItem("Duct tape", note: "Wrapped around pump"),
                    PackItem("Zip ties"),
                    PackItem("Leatherman", optional: true),
                    PackItem("Shock pump", note: "For suspension", optional: true),
                ]),
                ("Tire Repair", [
                    PackItem("Mini pump", note: "High-volume ~100cc"),
                    PackItem("Tire plugs", note: "Small + oversized"),
                    PackItem("Extra sealant", note: "2-4oz"),
                    PackItem("Spare tubes", note: "1-2"),
                    PackItem("Tire levers"),
                    PackItem("Tire boot"),
                    PackItem("Patch kit"),
                    PackItem("Super glue"),
                    PackItem("CO2 + nozzle", optional: true),
                ]),
                ("Spares", [
                    PackItem("Master links", note: "x2"),
                    PackItem("Derailleur hanger"),
                    PackItem("Brake pads", note: "2 pairs for 100+ miles"),
                    PackItem("Spare bolts"),
                    PackItem("Spare cleats", optional: true),
                    PackItem("Spare cables", optional: true),
                ]),
            ]
        ),
        PackCategory(
            id: "clothing", name: "Clothing & Layers", icon: "tshirt", color: .purple,
            subcategories: [
                ("On-Bike", [
                    PackItem("Riding shorts or bibs"),
                    PackItem("Chamois or underwear"),
                    PackItem("Merino wool jersey"),
                    PackItem("Wool socks"),
                    PackItem("Cycling shoes"),
                    PackItem("Helmet"),
                    PackItem("Cycling gloves"),
                    PackItem("Sunglasses"),
                ]),
                ("Spare / Off-Bike", [
                    PackItem("Extra socks"),
                    PackItem("T-shirt"),
                    PackItem("Extra chamois/bibs"),
                    PackItem("Long-sleeve merino top"),
                    PackItem("Rain jacket", note: "May storms in Black Hills"),
                    PackItem("Arm/leg warmers"),
                    PackItem("Lightweight down jacket", note: "Night temps drop to 30s", optional: true),
                    PackItem("Rain pants", optional: true),
                    PackItem("Merino leggings", optional: true),
                ]),
                ("Accessories", [
                    PackItem("Buff or neck gaiter"),
                    PackItem("Hat or beanie", optional: true),
                    PackItem("Camp shoes or sandals", optional: true),
                ]),
                ("Toiletries", [
                    PackItem("Toothbrush + paste"),
                    PackItem("Toilet paper"),
                    PackItem("Trowel"),
                    PackItem("Sunscreen + lip balm SPF"),
                    PackItem("Biodegradable soap"),
                    PackItem("Ear plugs", optional: true),
                ]),
            ]
        ),
        PackCategory(
            id: "electronics", name: "Electronics & Extras", icon: "bolt.fill", color: .yellow,
            subcategories: [
                ("Electronics", [
                    PackItem("iPhone 17 Pro", note: "Geotagging ON"),
                    PackItem("Garmin 810", note: "Route loaded, charged"),
                    PackItem("Fuji X-T50 + spare battery", note: "Primary camera"),
                    PackItem("Fuji X-M5 + spare battery", note: "Backup", optional: true),
                    PackItem("SD cards", note: "2x per camera"),
                    PackItem("USB-C cables", note: "x2"),
                    PackItem("Battery pack", note: "20,000mAh minimum"),
                    PackItem("Headlamp + spare battery"),
                    PackItem("Outlet charger cube"),
                ]),
                ("Extras", [
                    PackItem("Book or Kindle", optional: true),
                    PackItem("Camp chair or sit pad", optional: true),
                ]),
            ]
        ),
        PackCategory(
            id: "safety", name: "Safety & First Aid", icon: "cross.case", color: .green,
            subcategories: [
                ("Safety", [
                    PackItem("Satellite SOS enabled", note: "iPhone Settings > Emergency SOS"),
                    PackItem("Emergency contact set", note: "Nicole in StoneBC app"),
                    PackItem("Paper map of Black Hills"),
                    PackItem("Rear blinkie light"),
                    PackItem("Bell"),
                    PackItem("Bear spray", optional: true),
                    PackItem("Emergency whistle", optional: true),
                ]),
                ("First Aid", [
                    PackItem("Ibuprofen"),
                    PackItem("Gauze bandage"),
                    PackItem("Antiseptic pads"),
                    PackItem("Tweezers"),
                    PackItem("Butterfly bandages"),
                    PackItem("Antibiotic ointment"),
                    PackItem("Benadryl"),
                    PackItem("Blister kit"),
                ]),
            ]
        ),
        PackCategory(
            id: "bags", name: "Bike Bags", icon: "bag", color: .brown,
            subcategories: [
                ("Bags", [
                    PackItem("Frame bag"),
                    PackItem("Seat bag"),
                    PackItem("Handlebar bag or roll"),
                    PackItem("Feed bags", note: "x2 for snacks + camera access"),
                    PackItem("Top tube bag", note: "Phone + quick items"),
                ]),
            ]
        ),
    ]

    static var totalItems: Int {
        categories.reduce(0) { $0 + $1.allItems.count }
    }

    static var requiredItems: Int {
        categories.reduce(0) { $0 + $1.allItems.filter { !$0.isOptional }.count }
    }
}

// MARK: - View

struct PackingListView: View {
    let tripId: String // unique per trip for persistent checks

    @State private var checked: Set<String> = []
    @State private var showOptional = true
    @State private var expandedCategories: Set<String> = Set(BikepackingPackList.categories.map(\.id))

    private var storageKey: String { "packList-\(tripId)" }

    private var totalRequired: Int { BikepackingPackList.requiredItems }
    private var checkedRequired: Int {
        BikepackingPackList.categories.reduce(0) { total, cat in
            total + cat.allItems.filter { !$0.isOptional && checked.contains($0.id) }.count
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress header
            progressHeader

            // List
            ScrollView {
                LazyVStack(spacing: BCSpacing.md) {
                    ForEach(BikepackingPackList.categories) { category in
                        categorySection(category)
                    }
                }
                .padding(.horizontal, BCSpacing.md)
                .padding(.vertical, BCSpacing.sm)
            }
        }
        .navigationTitle("Pack List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Show Optional Items", isOn: $showOptional)
                    Button("Reset All") {
                        checked.removeAll()
                        saveChecked()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { loadChecked() }
    }

    // MARK: - Progress

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(checkedRequired)/\(totalRequired) required items packed")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(checked.count) total checked")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            ProgressView(value: Double(checkedRequired), total: Double(max(totalRequired, 1)))
                .tint(checkedRequired == totalRequired ? BCColors.brandGreen : BCColors.brandBlue)

            if checkedRequired == totalRequired {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(BCColors.brandGreen)
                    Text("All required items packed!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(BCColors.brandGreen)
                }
            }
        }
        .padding(.horizontal, BCSpacing.md)
        .padding(.vertical, 10)
        .background(BCColors.cardBackground)
    }

    // MARK: - Category Section

    private func categorySection(_ category: PackCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if expandedCategories.contains(category.id) {
                        expandedCategories.remove(category.id)
                    } else {
                        expandedCategories.insert(category.id)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: category.icon)
                        .font(.system(size: 14))
                        .foregroundColor(category.color)
                        .frame(width: 28, height: 28)
                        .background(category.color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text(category.name.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.primary)

                    Spacer()

                    // Category progress
                    let catItems = category.allItems.filter { showOptional || !$0.isOptional }
                    let catChecked = catItems.filter { checked.contains($0.id) }.count
                    Text("\(catChecked)/\(catItems.count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(catChecked == catItems.count ? BCColors.brandGreen : .secondary)

                    Image(systemName: expandedCategories.contains(category.id) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(BCSpacing.sm)
            }
            .buttonStyle(.plain)

            // Items
            if expandedCategories.contains(category.id) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(category.subcategories, id: \.name) { sub in
                        if sub.name != category.subcategories.first?.name {
                            Divider().padding(.leading, 44)
                        }

                        Text(sub.name.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundColor(category.color.opacity(0.7))
                            .padding(.leading, 44)
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                        ForEach(sub.items.filter { showOptional || !$0.isOptional }) { item in
                            itemRow(item, color: category.color)
                        }
                    }
                }
                .padding(.bottom, BCSpacing.sm)
            }
        }
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Item Row

    private func itemRow(_ item: PackItem, color: Color) -> some View {
        Button {
            toggle(item.id)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: checked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(checked.contains(item.id) ? BCColors.brandGreen : Color.secondary.opacity(0.4))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .medium))
                            .strikethrough(checked.contains(item.id))
                            .foregroundColor(checked.contains(item.id) ? .secondary : .primary)

                        if item.isOptional {
                            Text("optional")
                                .font(.system(size: 7, weight: .medium))
                                .tracking(0.5)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }

                    if let note = item.note {
                        Text(note)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, BCSpacing.sm)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Persistence

    private func toggle(_ id: String) {
        if checked.contains(id) {
            checked.remove(id)
        } else {
            checked.insert(id)
        }
        saveChecked()
    }

    private func loadChecked() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let set = try? JSONDecoder().decode(Set<String>.self, from: data) {
            checked = set
        }
    }

    private func saveChecked() {
        if let data = try? JSONEncoder().encode(checked) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

#Preview {
    NavigationStack {
        PackingListView(tripId: "8over7-2026")
    }
}
