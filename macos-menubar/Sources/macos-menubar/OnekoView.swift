import Cocoa
import SwiftUI
import MediaPlayer

struct OnekoView: View {
    @ObservedObject var state: AppState
    @State private var catPos: CGPoint = CGPoint(x: -16, y: -16)
    @State private var direction: Direction = .right
    @State private var sleepTick = 50
    @State private var tickCounter = 0
    @State private var frameNo = 25
    @State private var surpriseTick = 0
    @State private var showHeart = false
    @State private var normalTickCounter = 0
    
    enum Direction { case right, down, left, up }
    
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let url = Bundle.module.url(forResource: "\(frameNo)", withExtension: "gif"),
                   let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .overlay(
                            Text("❤️")
                                .font(.system(size: 16))
                                .opacity(showHeart ? 1 : 0)
                                .offset(y: showHeart ? -30 : -10)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                showHeart = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                withAnimation { showHeart = false }
                            }
                            surpriseTick = 5
                        }
                        .position(catPos)
                }
            }
            .onReceive(timer) { _ in
                if state.currentEasterEgg == .hyperSpeed || state.currentEasterEgg == .reverseSpin {
                    updateCat(size: geo.size, hyper: true)
                } else {
                    normalTickCounter += 1
                    if normalTickCounter % 7 == 0 {
                        updateCat(size: geo.size, hyper: false)
                    }
                }
            }
        }
    }
    
    func updateCat(size: CGSize, hyper: Bool = false) {
        tickCounter += 1
        
        if surpriseTick > 0 {
            surpriseTick -= 1
            frameNo = 32
            return
        }
        
        if showHeart {
            frameNo = 32 // stop and stare
            return
        }
        
        if state.status.paused {
            if sleepTick < 10 { sleepTick = 100 }
        } else if sleepTick > 0 {
            sleepTick = 0
            surpriseTick = 3
        }
        
        if sleepTick > 0 {
            sleepTick -= 1
            let slowTick = sleepTick / 4
            if sleepTick > 80 {
                frameNo = (slowTick % 2 == 0) ? 31 : 25 // lick
            } else if sleepTick > 40 {
                frameNo = (slowTick % 2 == 0) ? 27 : 28 // scratch
            } else if sleepTick > 30 {
                frameNo = 26 // yawn
            } else {
                frameNo = ((sleepTick / 8) % 2 == 0) ? 29 : 30 // sleep slowly
            }
            
            if sleepTick == 0 {
                surpriseTick = 4
            }
            return
        }
        
        var speed: CGFloat = 4
        if hyper {
            speed = state.currentEasterEgg == .reverseSpin ? -15 : 30
        }
        
        switch direction {
        case .right:
            frameNo = (frameNo == 5) ? 6 : 5 // Right frames
            catPos.x += speed
            if catPos.x >= size.width + 16 {
                catPos.x = size.width + 16
                direction = .down
                maybeSleep()
            } else if catPos.x <= -16 {
                catPos.x = -16
                direction = .up
            }
        case .down:
            frameNo = (frameNo == 9) ? 10 : 9 // Down frames
            catPos.y += speed
            if catPos.y >= size.height + 16 {
                catPos.y = size.height + 16
                direction = .left
                maybeSleep()
            } else if catPos.y <= -16 {
                catPos.y = -16
                direction = .right
            }
        case .left:
            frameNo = (frameNo == 13) ? 14 : 13 // Left frames
            catPos.x -= speed
            if catPos.x <= -16 {
                catPos.x = -16
                direction = .up
                maybeSleep()
            } else if catPos.x >= size.width + 16 {
                catPos.x = size.width + 16
                direction = .down
            }
        case .up:
            frameNo = (frameNo == 1) ? 2 : 1 // Up frames
            catPos.y -= speed
            if catPos.y <= -16 {
                catPos.y = -16
                direction = .right
                maybeSleep()
            } else if catPos.y >= size.height + 16 {
                catPos.y = size.height + 16
                direction = .left
            }
        }
    }
    
    func maybeSleep() {
        if Int.random(in: 0...2) == 0 {
            sleepTick = 100
        }
    }
}
