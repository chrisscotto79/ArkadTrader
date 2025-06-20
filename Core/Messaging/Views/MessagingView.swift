
import SwiftUI

struct MessagingView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Messages")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Messaging functionality coming soon!")
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .navigationTitle("Messages")
            .padding()
        }
    }
}

#Preview {
    MessagingView()
