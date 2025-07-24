import SwiftUI

enum SettingsTab {
    case first, second, third
}

struct SettingsView: View {
    @State var selected: SettingsTab = .first

    var body: some View {
        VStack {
            HStack {
                Button {
                } label: {
                    Image(systemName: "star")
                        .frame(width: 20, height: 20)
                }
                Button {
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 20, height: 20)
                }
                Button {
                } label: {
                    Image(systemName: "square.and.arrow.down.badge.clock")
                        .frame(width: 20, height: 20)
                }
                Button {
                } label: {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .frame(width: 20, height: 20)
                }
            }
            VStack {
                Text("Settings go here")
            }.frame(minHeight: 100)
        }.padding()
    }
}
