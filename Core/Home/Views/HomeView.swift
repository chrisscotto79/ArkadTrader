// File: Core/Home/Views/HomeView.swift

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var posts: [Post] = []
    @State private var newPostContent = ""
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack {
                // New Post Section
                VStack {
                    TextField("What's on your mind?", text: $newPostContent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button("Post") {
                        Task {
                            await createPost()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(newPostContent.isEmpty)
                }
                .padding()

                // Posts List
                if posts.isEmpty && !isLoading {
                    VStack {
                        Text("No posts yet")
                            .foregroundColor(.gray)
                        Text("Be the first to post!")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 50)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(posts) { post in
                                PostCardView(post: post)
                            }
                        }
                        .padding()
                    }
                }

                Spacer()
            }
            .navigationTitle("Home")
            .onAppear {
                Task {
                    await loadPosts()
                }
            }
        }
    }

    private func createPost() async {
        guard let userId = authService.currentUser?.id,
              let username = authService.currentUser?.username else { return }

        let newPost = Post(
            content: newPostContent,
            authorId: userId,
            authorUsername: username
        )

        do {
            try await authService.createPost(newPost)
            newPostContent = ""
            await loadPosts()
        } catch {
            print("Error creating post: \(error)")
        }
    }

    private func loadPosts() async {
        isLoading = true
        do {
            posts = try await authService.getFeedPosts()
        } catch {
            print("Error loading posts: \(error)")
        }
        isLoading = false
    }
}
