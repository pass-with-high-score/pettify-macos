import Cocoa
import SwiftUI
import MediaPlayer

struct AudioVisualizerView: View {
    var isPlaying: Bool
    @State private var heights: [CGFloat] = [0.2, 0.4, 0.6, 0.3]
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 3, height: isPlaying ? heights[i] * 12 : 3)
                    .animation(.easeInOut(duration: 0.15), value: heights[i])
            }
        }
        .frame(height: 12, alignment: .bottom)
        .onReceive(timer) { _ in
            if isPlaying {
                for i in 0..<4 {
                    heights[i] = CGFloat.random(in: 0.2...1.0)
                }
            }
        }
    }
}
