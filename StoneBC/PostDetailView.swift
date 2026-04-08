//
//  PostDetailView.swift
//  StoneBC
//
//  Full post with markdown rendering
//

import SwiftUI

struct PostDetailView: View {
    let post: Post

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: BCSpacing.sm) {
                    Text(post.title)
                        .font(.system(size: 22, weight: .bold))

                    HStack {
                        if let category = post.category {
                            HStack(spacing: 4) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 10))
                                Text(category.label)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(category.color)
                        }

                        Spacer()

                        Text(post.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Body — render as markdown
                if let attributed = try? AttributedString(markdown: post.body) {
                    Text(attributed)
                        .font(.system(size: 15, weight: .regular))
                        .lineSpacing(6)
                        .foregroundColor(.primary)
                } else {
                    Text(post.body)
                        .font(.system(size: 15, weight: .regular))
                        .lineSpacing(6)
                        .foregroundColor(.primary)
                }
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("POST")
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PostDetailView(post: .preview)
    }
}
