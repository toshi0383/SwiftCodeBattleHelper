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
                        copiedMessage
                    }
                    ToolbarItem(placement: .automatic) {
                        copyButton
                    }
                    ToolbarItem(placement: .automatic) {
                        executeButton
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
    private var copiedMessage: some View {
        Text("コピーしました")
            .foregroundStyle(.green)
            .opacity(viewModel.isCopySuccessfulStateVisible ? 1 : 0)
            .animation(.bouncy(duration: 0.2), value: viewModel.isCopySuccessfulStateVisible)
            .onChange(of: viewModel.isCopySuccessfulStateVisible) {
                if viewModel.isCopySuccessfulStateVisible {
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        viewModel.isCopySuccessfulStateVisible = false
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
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

    @ViewBuilder
    private var executeButton: some View {
        Button {
            if let selectedFileURL {
                viewModel.executeCommand(selectedFileURL: selectedFileURL)
            }
        } label: {
            Text("実行")
        }
        .keyboardShortcut(.return, modifiers: [.command])
    }

    @ViewBuilder
    private var copyButton: some View {
        Button {
            viewModel.onClickCopyButton()
        } label: {
            Text("コピー")
        }
        .keyboardShortcut("c", modifiers: [.command])
    }
}

#Preview {
    ContentView()
}
