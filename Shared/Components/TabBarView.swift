
import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            Text("Home Tab")
                .font(.largeTitle)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            // Search Tab
            Text("Search Tab")
                .font(.largeTitle)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(1)
            
            // Portfolio Tab
            Text("Portfolio Tab")
                .font(.largeTitle)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Portfolio")
                }
                .tag(2)
            
            // Messaging Tab
            Text("Messaging Tab")
                .font(.largeTitle)
                .tabItem {
                    Image(systemName: "envelope.fill")
                    Text("Messaging")
                }
                .tag(3)
            
            // Profile Tab
            Text("Profile Tab")
                .font(.largeTitle)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
    }
}
