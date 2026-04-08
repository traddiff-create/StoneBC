//
//  BikeFilterBar.swift
//  StoneBC
//
//  Horizontal filter chips for bike status and type
//

import SwiftUI

struct BikeFilterBar: View {
    @Binding var selectedStatus: BikeStatus?
    @Binding var selectedType: BikeType?
    let bikes: [Bike]

    private func statusCount(_ status: BikeStatus) -> Int {
        bikes.filter { $0.status == status }.count
    }

    private func typeCount(_ type: BikeType) -> Int {
        bikes.filter { $0.type == type }.count
    }

    private var activeTypes: [BikeType] {
        BikeType.allCases.filter { type in
            bikes.contains { $0.type == type }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BCSpacing.xs) {
                    // Status filters
                    FilterChip(
                        title: "All",
                        count: bikes.count,
                        isSelected: selectedStatus == nil && selectedType == nil
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedStatus = nil
                            selectedType = nil
                        }
                    }

                    ForEach([BikeStatus.available, .refurbishing, .sponsored], id: \.self) { status in
                        let count = statusCount(status)
                        if count > 0 {
                            FilterChip(
                                title: status.label,
                                count: count,
                                isSelected: selectedStatus == status
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedStatus = selectedStatus == status ? nil : status
                                }
                            }
                        }
                    }

                    // Divider
                    if !activeTypes.isEmpty {
                        Rectangle()
                            .fill(BCColors.divider)
                            .frame(width: 1, height: 20)
                            .padding(.horizontal, 4)
                    }

                    // Type filters
                    ForEach(activeTypes, id: \.self) { type in
                        FilterChip(
                            title: type.label,
                            count: typeCount(type),
                            isSelected: selectedBikeType == type
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedType = selectedType == type ? nil : type
                            }
                        }
                    }
                }
                .padding(.horizontal, BCSpacing.md)
                .padding(.vertical, 12)
            }
            .background(BCColors.background)

            Divider()
        }
    }

    private var selectedBikeType: BikeType? {
        selectedType
    }
}

#Preview {
    BikeFilterBar(
        selectedStatus: .constant(nil),
        selectedType: .constant(nil),
        bikes: [.preview]
    )
}
