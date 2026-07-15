import Cocoa
import SwiftUI
import MediaPlayer

struct OnekoView: View {
    @ObservedObject var state: AppState
    @State private var catPos: CGPoint = CGPoint(x: -16, y: -16)
    @State private var direction: Direction = .right
    @State private var idleTick = 0         // Short idle break (wash/scratch) while music plays
    @State private var sleepTick = 0        // Deep sleep when paused
    @State private var tickCounter = 0
    @State private var frameName = "wash2"
    @AppStorage("nekoSkin") private var nekoSkin = "neko"
    @AppStorage("nekoSpeed") private var nekoSpeed = 4.0
    @AppStorage("nekoSize") private var nekoSize = 32.0
    @AppStorage("nekoWallClaw") private var nekoWallClaw = true
    @AppStorage("nekoScreenEdge") private var nekoScreenEdge = false
    
    @State private var surpriseTick = 0
    @State private var showHeart = false
    @State private var wallClawTick = 0
    @State private var wasPaused = false    // Track pause state changes
    
    enum Direction { case right, down, left, up }
    
    // Timer fires every 33ms (~30fps)
    let timer = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()
    
    /// Half the neko size, used for edge margin
    private var halfSize: CGFloat { nekoSize / 2 }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let url = Bundle.module.url(forResource: frameName, withExtension: "png", subdirectory: "Skins/\(nekoSkin)"),
                   let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: nekoSize, height: nekoSize)
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
                            surpriseTick = 8
                        }
                        .position(catPos)
                } else if let fallbackUrl = Bundle.module.url(forResource: frameName, withExtension: "png", subdirectory: "Skins/neko"),
                          let fallbackImage = NSImage(contentsOf: fallbackUrl) {
                    Image(nsImage: fallbackImage)
                        .resizable()
                        .frame(width: nekoSize, height: nekoSize)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .position(catPos)
                }
            }
            .onReceive(timer) { _ in
                let bounds: CGSize
                if nekoScreenEdge, let screen = NSScreen.main {
                    bounds = screen.visibleFrame.size
                } else {
                    bounds = geo.size
                }
                let isHyper = state.currentEasterEgg == .hyperSpeed || state.currentEasterEgg == .reverseSpin
                updateCat(size: bounds, hyper: isHyper)
            }
            .onAppear {
                wasPaused = state.status.paused
            }
        }
    }
    
    func updateCat(size: CGSize, hyper: Bool = false) {
        tickCounter += 1
        
        // Throttle: normal speed updates every 3 ticks (~10fps), hyper every tick
        if !hyper && tickCounter % 3 != 0 {
            return
        }
        
        // --- Surprise / Tap reaction ---
        if surpriseTick > 0 {
            surpriseTick -= 1
            frameName = "awake"
            return
        }
        
        if showHeart {
            frameName = "awake"
            return
        }
        
        // --- Wall claw animation ---
        if wallClawTick > 0 {
            wallClawTick -= 1
            let isClaw1 = (wallClawTick / 6) % 2 == 0
            switch direction {
            case .right: frameName = isClaw1 ? "rightclaw1" : "rightclaw2"
            case .left: frameName = isClaw1 ? "leftclaw1" : "leftclaw2"
            case .up: frameName = isClaw1 ? "upclaw1" : "upclaw2"
            case .down: frameName = isClaw1 ? "downclaw1" : "downclaw2"
            }
            
            if wallClawTick == 0 {
                switch direction {
                case .right: direction = .down
                case .down: direction = .left
                case .left: direction = .up
                case .up: direction = .right
                }
                maybeIdle()
            }
            return
        }
        
        // --- Pause/Resume detection ---
        let isPaused = state.status.paused
        
        // Just paused → start deep sleep
        if isPaused && !wasPaused {
            wasPaused = true
            sleepTick = 100
            idleTick = 0
        }
        // Just resumed → wake up!
        if !isPaused && wasPaused {
            wasPaused = false
            sleepTick = 0
            idleTick = 0
            surpriseTick = 6
            return
        }
        
        // --- Deep sleep (music paused) ---
        if sleepTick > 0 {
            sleepTick -= 1
            if sleepTick > 80 {
                frameName = "wash2"          // lick/wash
            } else if sleepTick > 40 {
                frameName = ((sleepTick / 8) % 2 == 0) ? "scratch1" : "scratch2"
            } else if sleepTick > 30 {
                frameName = "yawn2"          // yawn
            } else {
                frameName = ((sleepTick / 12) % 2 == 0) ? "sleep1" : "sleep2"
            }
            
            if sleepTick == 0 {
                if isPaused {
                    // Still paused → keep sleeping
                    sleepTick = 80
                } else {
                    surpriseTick = 6
                }
            }
            return
        }
        
        // --- Short idle break (music playing) ---
        if idleTick > 0 {
            idleTick -= 1
            if idleTick > 30 {
                frameName = "wash2"          // quick wash
            } else if idleTick > 10 {
                frameName = ((idleTick / 6) % 2 == 0) ? "scratch1" : "scratch2"
            } else {
                frameName = "yawn2"          // small yawn
            }
            
            if idleTick == 0 {
                surpriseTick = 4             // wake up and resume running
            }
            return
        }
        
        // --- Movement ---
        var speed: CGFloat = nekoSpeed
        if hyper {
            speed = state.currentEasterEgg == .reverseSpin ? -15 : 30
        }
        
        // Alternate walk frames every 2 movement-ticks
        let walkFrame = (tickCounter / 3 / 2) % 2
        
        switch direction {
        case .right:
            frameName = walkFrame == 0 ? "right1" : "right2"
            catPos.x += speed
            if catPos.x >= size.width - halfSize {
                catPos.x = size.width - halfSize
                handleEdgeHit(from: .right)
            } else if catPos.x <= halfSize {
                catPos.x = halfSize
                direction = .up
            }
        case .down:
            frameName = walkFrame == 0 ? "down1" : "down2"
            catPos.y += speed
            if catPos.y >= size.height - halfSize {
                catPos.y = size.height - halfSize
                handleEdgeHit(from: .down)
            } else if catPos.y <= halfSize {
                catPos.y = halfSize
                direction = .right
            }
        case .left:
            frameName = walkFrame == 0 ? "left1" : "left2"
            catPos.x -= speed
            if catPos.x <= halfSize {
                catPos.x = halfSize
                handleEdgeHit(from: .left)
            } else if catPos.x >= size.width - halfSize {
                catPos.x = size.width - halfSize
                direction = .down
            }
        case .up:
            frameName = walkFrame == 0 ? "up1" : "up2"
            catPos.y -= speed
            if catPos.y <= halfSize {
                catPos.y = halfSize
                handleEdgeHit(from: .up)
            } else if catPos.y >= size.height - halfSize {
                catPos.y = size.height - halfSize
                direction = .left
            }
        }
    }
    
    func handleEdgeHit(from currentDir: Direction) {
        if nekoWallClaw && Int.random(in: 0...2) == 0 {
            wallClawTick = Int.random(in: 20...40)
        } else {
            switch currentDir {
            case .right: direction = .down
            case .down: direction = .left
            case .left: direction = .up
            case .up: direction = .right
            }
            maybeIdle()
        }
    }
    
    /// Random chance to take a short break (wash/scratch/yawn) then resume
    func maybeIdle() {
        if Int.random(in: 0...3) == 0 {
            idleTick = Int.random(in: 30...50)  // Short idle break
        }
    }
}
