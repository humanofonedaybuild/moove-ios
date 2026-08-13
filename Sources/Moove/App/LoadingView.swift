import MooveKit
import SwiftUI

/// Full-screen launch/loading state shown immediately at app start.
///
/// Displays only the Moove monogram and wordmark over the Warm Editorial
/// cream surface — no navigation chrome, tabs, or status-bar clutter. The view
/// is presented as an overlay above `ContentView` so an alarm mission that fires
/// on cold-start is never blocked behind the brand moment: `ContentView` is
/// already live underneath and can present its full-screen mission immediately.
struct LoadingView: View {
    @State private var monogramOpacity: Double = 0
    @State private var monogramScale: CGFloat = 0.92

    var body: some View {
        ZStack {
            Color.terracotta.ignoresSafeArea()

            VStack(spacing: MooveSpacing.md) {
                Image("MooveMonogram")
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 168, maxHeight: 168)
                    .opacity(monogramOpacity)
                    .scaleEffect(monogramScale)
                    .accessibilityHidden(true)

                Text("Moove")
                    .font(MooveFont.wordmark())
                    .foregroundStyle(Color.loadingWordmark)
                    .tracking(2.4)
                    .opacity(monogramOpacity)
                    .accessibilityHidden(true)
            }
        }
        .transition(.opacity)
        .accessibilityIdentifier("launch.loadingView")
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: MooveAnimationDuration.standard + 0.15)) {
            monogramOpacity = 1
            monogramScale = 1
        }
    }
}

#Preview {
    LoadingView()
}
