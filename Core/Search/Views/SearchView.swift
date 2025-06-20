import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Search functionality coming soon!")
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .navigationTitle("Search")
            .padding()
        }
    }
}

#Preview {
    SearchView()
}
