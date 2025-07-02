import SwiftUI

@main
struct ArkadTraderApp: App {
    @State private var showSplash = true
    @State private var bounce = false
    @State private var opacity = 1.0
    @State private var logoIndex = 0


    let logos = [
        URL(string: "https://arkadwealthgroup.com/wp-content/uploads/2025/01/ARKAD_BLACK.png")!,
    ]
    

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    Color.white.ignoresSafeArea()

                    VStack {
                        Spacer()

                        AsyncImage(url: logos[logoIndex]) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            Color.clear
                        }
                        .frame(width: 220, height: 220)
                        .offset(y: bounce ? -20 : 20)
                        .opacity(opacity)
                        .onAppear {
                            bounceLogo()
                            changeLogo()
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }

    func bounceLogo() {
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
            bounce.toggle()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSplash = false
            }
        }
    }

    func changeLogo() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            logoIndex = (logoIndex + 1) % logos.count
        }
    }
}

