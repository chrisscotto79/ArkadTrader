import SwiftUI

struct FeedView: View {
    // Add the missing homeViewModel property
    @StateObject private var homeViewModel = HomeViewModel()
    
    var body: some View {
        // Pass the homeViewModel to MarketNewsFeedView
        MarketNewsFeedView(homeViewModel: homeViewModel)
    }
}

#Preview {
    FeedView()
}
