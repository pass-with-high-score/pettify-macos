import Cocoa
import SwiftUI
import MediaPlayer

struct CustomSlider: View {
    @Binding var value: Double
    var total: Double
    var onEditingChanged: () -> Void = {}
    
    @State private var isDragging = false
    @State private var dragValue: Double?
    @State private var isHovering = false
    
    var body: some View {
        GeometryReader { geo in
            let displayValue = isDragging ? (dragValue ?? value) : value
            let percent = max(0, min(1, total > 0 ? displayValue / total : 0))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.2)).frame(height: 4)
                Capsule().fill(Color.accentColor).frame(width: geo.size.width * CGFloat(percent), height: 4)
                
                let thumbSize: CGFloat = isDragging || isHovering ? 10 : 8
                let thumbOffset: CGFloat = isDragging || isHovering ? 5 : 4
                
                Circle()
                    .fill(Color.primary)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: max(0, min(geo.size.width * CGFloat(percent) - thumbOffset, geo.size.width - thumbSize)))
                    .shadow(color: .black.opacity(0.2), radius: 2)
            }
            .frame(height: 12, alignment: .center)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovering = hovering
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let percentage = min(max(0, drag.location.x / geo.size.width), 1)
                        dragValue = Double(percentage) * total
                    }
                    .onEnded { drag in
                        isDragging = false
                        let percentage = min(max(0, drag.location.x / geo.size.width), 1)
                        value = Double(percentage) * total
                        onEditingChanged()
                    }
            )
        }
        .frame(height: 12)
    }
}

struct CustomProgressBar: View {
    var value: Double
    var total: Double
    
    var body: some View {
        GeometryReader { geo in
            let percent = max(0, min(1, total > 0 ? value / total : 0))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.3)).frame(height: 4)
                Capsule().fill(Color.white).frame(width: geo.size.width * CGFloat(percent), height: 4)
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .offset(x: max(0, min(geo.size.width * CGFloat(percent) - 4, geo.size.width - 8)))
                    .shadow(color: .black.opacity(0.5), radius: 1)
            }
            .frame(height: 8, alignment: .center)
        }
        .frame(height: 8)
    }
}
