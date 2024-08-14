import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()
    @AppStorage("selectedFileURL") var selectedFileURL: URL?
    var body: some View {
        NavigationSplitView {
            VStack {
                List(viewModel.files, id: \.self) { file in
                    HStack {
                        Image(systemName: "swift")
                            .foregroundColor(.orange)
                        Text(file.deletingPathExtension().lastPathComponent)
                    }
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(file.lastPathComponent.hasPrefix(".") ? .secondary : .primary)
                    .listRowBackground(selectedFileURL == file ? Color.blue : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFileURL = file
                        viewModel.onSelectFile(url: file)
                    }
                }
                Text("Location: " + viewModel.directoryURL.path)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        } detail: {
            content
                .navigationTitle("SwiftCodeBattle")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            if let selectedFileURL {
                                viewModel.executeCommand(selectedFileURL: selectedFileURL)
                            }
                        } label: {
                            Text("実行")
                        }
                        .keyboardShortcut(.return, modifiers: [.command])
                    }

                }
                .onAppear {
                    viewModel.onAppear()
                }
                .onChange(of: viewModel.files, initial: true) {
                    if selectedFileURL == nil {
                        selectedFileURL = viewModel.files.first
                    }
                    if let selectedFileURL {
                        viewModel.onSelectFile(url: selectedFileURL)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
            VStack(spacing: 0) {
                if selectedFileURL != nil {
                    ScrollView {
                        Text(viewModel.fileContents)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 100)
                    .border(Color.gray, width: 1)
                    .padding(.vertical)
                } else {
                    Text("ファイルを選択してください")
                }
                EqualWidthHStack {
                    VStack(alignment: .leading) {
                        Text("stdin")
                        TextEditor(text: $viewModel.inputText)
                            .padding()
                            .background(.background)
                            .border(Color.gray, width: 1)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("stdout")
                            Spacer()
                            if let commandStatus = viewModel.commandStatus {
                                Text("code: \(commandStatus)")
                            }
                        }
                        ScrollView {
                            Text(viewModel.outputText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .background(.background)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
    }
}

#Preview {
    ContentView()
}
