import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()
    @AppStorage("directoryURL") var directoryURL: URL?
    @AppStorage("selectedFileURL") var selectedFileURL: URL?
    @AppStorage("inputText") var inputText: String = ""
    @State private var isFileImporterPresented = false
    var body: some View {
        NavigationSplitView {
            filePane
        } detail: {
            workspacePane
                .navigationTitle("Runtime Performance is the King")
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
                    if let directoryURL {
                        viewModel.onChangeDirectory(to: directoryURL)
                    }
                }
                .onChange(of: directoryURL, initial: true) {
                    selectedFileURL = viewModel.files.first
                    if let selectedFileURL {
                        viewModel.onSelectFile(url: selectedFileURL)
                    }
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
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    directoryURL = url
                    viewModel.onChangeDirectory(to: url)
                }
            case .failure(let error):
                print("Error selecting directory: \(error.localizedDescription)")
            }
        }
    }


    @ViewBuilder
    private var filePane: some View {
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
            if let directoryURL {
                Text("Location: " + directoryURL.path)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            Button("Change Location") {
                isFileImporterPresented = true
            }
            .padding()
        }
    }

    @ViewBuilder
    private var workspacePane: some View {
        VStack(spacing: 0) {
            if selectedFileURL != nil {
                ScrollView {
                    Text(viewModel.fileContents)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(minHeight: 100)
                .overlay(countText, alignment: .bottomTrailing)
                .border(Color.gray, width: 1)
                .padding(.vertical)
            } else {
                Text("ファイルを選択してください")
            }
            EqualWidthHStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Text("stdin")
                        pasteButton
                        deleteButton
                    }
                    TextEditor(text: $inputText)
                        .font(.body.monospaced())
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
                            .font(.body.monospaced())
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
    private var countText: some View {
        Text("count: \(viewModel.characterCount)")
            .foregroundStyle(.secondary)
            .padding()
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
    private var executeButton: some View {
        Button {
            if let selectedFileURL {
                viewModel.executeCommand(selectedFileURL: selectedFileURL, inputText: inputText)
            }
        } label: {
            Text("実行")
        }
        .keyboardShortcut(.return, modifiers: [.command])
    }

    @ViewBuilder
    private var pasteButton: some View {
        Button {
            let pasteboard = NSPasteboard.general
            if let s = pasteboard.string(forType: .string) {
                inputText = s
            }
        } label: {
            Text("paste")
        }
        .keyboardShortcut("p", modifiers: [.command])
    }
    @ViewBuilder
    private var deleteButton: some View {
        Button {
            inputText = ""
        } label: {
            Image(systemName: "trash")
        }
        .keyboardShortcut(.delete, modifiers: [.command])
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
