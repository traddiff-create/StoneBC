//
//  CommunityFeedView.swift
//  StoneBC
//
//  Owner-authored community bulletin board
//

import SwiftUI

struct CommunityFeedView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        NavigationStack {
            Group {
                if appState.sortedPosts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(appState.sortedPosts) { post in
                                NavigationLink(destination: PostDetailView(post: post)) {
                                    PostCardRow(post: post)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, BCSpacing.md)
                        .padding(.top, BCSpacing.sm)
                        .padding(.bottom, BCSpacing.xl)
                    }
                }
            }
            .background(BCColors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("COMMUNITY")
                            .font(.bcSectionTitle)
                            .tracking(2)
                        Text("\(appState.sortedPosts.count) posts")
                            .font(.bcMicro)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: BCSpacing.md) {
            Spacer()
            Image(systemName: "bubble.left")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No posts yet")
                .font(.bcPrimaryText)
                .foregroundColor(.secondary)
            Text("Check back soon for updates")
                .font(.bcSecondaryText)
                .foregroundColor(BCColors.tertiaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CommunityFeedView()
        .environment(AppState())
}
