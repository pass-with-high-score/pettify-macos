import Cocoa
import SwiftUI
import MediaPlayer

struct FloatingNote: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var opacity: Double
    var symbol: String
    var color: Color
}

struct FloatingNotesView: View {
    var isPlaying: Bool
    @State private var notes: [FloatingNote] = []
    let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    
    let symbols = ["music.note", "music.quarternote.3", "sparkles", "heart.fill", "star.fill"]
    let colors: [Color] = [.pink, .purple, .cyan, .mint, .orange, .yellow]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(notes) { note in
                    Image(systemName: note.symbol)
                        .font(.system(size: 14))
                        .foregroundColor(note.color.opacity(0.8))
                        .scaleEffect(note.scale)
                        .position(x: note.x, y: note.y)
                        .opacity(note.opacity)
                        .animation(.easeOut(duration: 3.0), value: note.y)
                        .animation(.easeOut(duration: 3.0), value: note.opacity)
                }
            }
            .onReceive(timer) { _ in
                if isPlaying {
                    spawnNote(in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    func spawnNote(in size: CGSize) {
        let startX = CGFloat.random(in: 20...(size.width - 20))
        let startY = size.height
        
        let newNote = FloatingNote(
            x: startX,
            y: startY,
            scale: CGFloat.random(in: 0.6...1.2),
            opacity: 1.0,
            symbol: symbols.randomElement()!,
            color: colors.randomElement()!
        )
        
        notes.append(newNote)
        
        if notes.count > 10 {
            notes.removeFirst()
        }
        
        let id = newNote.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let index = notes.firstIndex(where: { $0.id == id }) {
                notes[index].y = startY - CGFloat.random(in: 60...120)
                notes[index].x += CGFloat.random(in: -40...40)
                notes[index].opacity = 0
            }
        }
    }
}
