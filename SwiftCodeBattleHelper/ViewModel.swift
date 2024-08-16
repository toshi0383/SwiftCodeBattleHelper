import SwiftUI
import Foundation

@MainActor
final class ViewModel: ObservableObject {
    @Published var outputText: String = ""
    @Published var fileContents: String = ""
    @Published var files: [URL] = []
    @Published var isCopySuccessfulStateVisible = false
    @Published private(set) var commandStatus: Int32?
    private var source: DispatchSourceFileSystemObject? = nil
    private let fileManager = FileManager.default
    let directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("dev/tmp/SwiftCodeBattleHelper/CLIApp")
    private var lastLoadedFileURL: URL?

    func onDirectoryChanged() {
        loadFiles()
        if let lastLoadedFileURL {
            loadFileContents(selectedFileURL: lastLoadedFileURL)
        }
    }
    func onAppear() {
        loadFiles()
        monitorFileChanges()
    }

    func onSelectFile(url: URL) {
        lastLoadedFileURL = url
        loadFileContents(selectedFileURL: url)
    }

    func onClickCopyButton() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fileContents, forType: .string)
        isCopySuccessfulStateVisible = true
    }

    func executeCommand(selectedFileURL: URL, inputText: String) {
        outputText = ""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [selectedFileURL.path]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe() // エラー出力用のパイプを追加

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe // エラー出力にパイプを設定

        do {
            try process.run()

            if let inputData = inputText.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(inputData)
            }
            inputPipe.fileHandleForWriting.closeFile()

            // 標準出力の読み取り
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let outputString = String(data: outputData, encoding: .utf8) ?? "エラー: 出力を読み取れませんでした。"

            // エラー出力の読み取り
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? ""

            // コマンドの終了ステータスを取得
            process.waitUntilExit()
            let status = process.terminationStatus

            // 出力を更新
            commandStatus = status
            if !errorString.isEmpty {
                outputText += "エラー: \(errorString)\n"
            }
            outputText += outputString

        } catch {
            outputText = "エラー: コマンドの実行に失敗しました。"
        }

        // TODO:
        // - 実行してからの経過時間をカウントする

    }

    private func loadFiles() {
        do {
            files = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
                .sorted(by: { a, _ in
                    !a.lastPathComponent.hasPrefix(".")
                })
        } catch {
            print("ディレクトリの読み込みに失敗しました: \(error)")
        }
    }

    private func loadFileContents(selectedFileURL: URL) {
        do {
            fileContents = try String(contentsOf: selectedFileURL, encoding: .utf8)
        } catch {
            if (error as NSError).code != 260 {
                fileContents = "ファイルの読み込みに失敗しました: \(error)"
            }
        }
    }

    private func monitorFileChanges() {
        let directoryFileDescriptor = open(directoryURL.path, O_EVTONLY)

        guard directoryFileDescriptor != -1 else {
            print("ディレクトリを監視できませんでした: \(directoryURL.path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: directoryFileDescriptor, eventMask: .all, queue: DispatchQueue.main)

        source.setEventHandler {
            self.onDirectoryChanged()
        }

        source.setCancelHandler {
            print("cancel")
            close(directoryFileDescriptor)
        }

        source.activate()
        self.source = source
    }
}
