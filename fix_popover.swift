import Foundation

let url = URL(fileURLWithPath: "macos-menubar/Sources/macos-menubar/PopoverView.swift")
var content = try! String(contentsOf: url)

let listCode = """
            if !state.queue.isEmpty {
                Divider()
                Text("Up Next")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(state.queue) { track in
                            HStack {
                                AsyncImage(url: URL(string: track.thumbnail)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.gray
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .cornerRadius(4)
                                
                                VStack(alignment: .leading) {
                                    Text(track.title).font(.caption).lineLimit(1)
                                    Text(track.artist).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
"""

content = content.replacingOccurrences(of: """
                Slider(value: Binding(
                    get: { state.status.volume },
                    set: { state.setVolume($0) }
                ), in: 0...1.5)
            }.padding(.horizontal, 20)
        }
        .padding(.vertical, 15)
""", with: """
                Slider(value: Binding(
                    get: { state.status.volume },
                    set: { state.setVolume($0) }
                ), in: 0...1.5)
            }.padding(.horizontal, 20)
            
\(listCode)
        }
        .padding(.vertical, 15)
""")

try! content.write(to: url, atomically: true, encoding: .utf8)
