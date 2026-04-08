//
//  PostCardRow.swift
//  StoneBC
//
//  Community feed card
//

import SwiftUI

struct PostCardRow: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            Text(post.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)

            // Excerpt
            Text(post.excerpt)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .lineSpacing(2)

            // Footer
            HStack {
                if let category = post.category {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 9))
                        Text(category.label.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.color.opacity(0.12))
                    .foregroundColor(category.color)
                    .clipShape(Capsule())
                }

                Spacer()

                Text(post.formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(BCColors.tertiaryText)
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(post.title). \(post.excerpt)")
    }
}

#Preview {
    PostCardRow(post: .preview)
        .padding()
        .background(BCColors.background)
}
