import SwiftUI
import Foundation

@MainActor
final class ViewModel: ObservableObject {
    @Published var outputText: String = ""
    @Published var fileContents: String = ""
    @Published var files: [URL] = []
    @Published var isCopySuccessfulStateVisible = false
    @Published private(set) var commandStatus: Int32?
    @Published private(set) var characterCount: Int = 0
    private var source: DispatchSourceFileSystemObject? = nil
    private let fileManager = FileManager.default
    private var directoryURL: URL?
    private var lastLoadedFileURL: URL?

    func onChangeDirectory(to newURL: URL) {
        self.directoryURL = newURL
        lastLoadedFileURL = nil
        loadFiles()
        monitorFileChanges()
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

        // 書き込み可能な一時ディレクトリを取得
        let tempDirectory = FileManager.default.temporaryDirectory
        let executableURL = tempDirectory.appendingPathComponent(UUID().uuidString) // 一意の名前を付ける

        // 1. swiftc file の実行
        let compileProcess = Process()
        compileProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        compileProcess.arguments = [selectedFileURL.path, "-o", executableURL.path]

        let errorPipe = Pipe() // エラー出力用のパイプ
        compileProcess.standardError = errorPipe

        do {
            try compileProcess.run()
            compileProcess.waitUntilExit()

            // コンパイル時のエラー出力の読み取り
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? ""

            if compileProcess.terminationStatus != 0, !errorString.isEmpty {
                outputText += "コンパイルエラー: \(errorString)\n"
            }

            // コンパイルに失敗した場合、ここで終了
            guard compileProcess.terminationStatus == 0 else {
                commandStatus = compileProcess.terminationStatus
                return
            }

        } catch {
            outputText = "エラー: swiftc の実行に失敗しました。"
            return
        }

        // 2. コンパイルしたファイルの実行
        let runProcess = Process()
        runProcess.executableURL = executableURL

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let runErrorPipe = Pipe()

        runProcess.standardInput = inputPipe
        runProcess.standardOutput = outputPipe
        runProcess.standardError = runErrorPipe

        do {
            try runProcess.run()

            if let inputData = inputText.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(inputData)
            }
            inputPipe.fileHandleForWriting.closeFile()

            // 実行時の標準出力の読み取り
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let outputString = String(data: outputData, encoding: .utf8) ?? "エラー: 出力を読み取れませんでした。"

            // 実行時のエラー出力の読み取り
            let runErrorData = runErrorPipe.fileHandleForReading.readDataToEndOfFile()
            let runErrorString = String(data: runErrorData, encoding: .utf8) ?? ""

            // 実行終了まで待機
            runProcess.waitUntilExit()
            let status = runProcess.terminationStatus

            // 出力を更新
            commandStatus = status
            if !runErrorString.isEmpty {
                outputText += "実行エラー: \(runErrorString)\n"
            }
            outputText += outputString

        } catch {
            outputText = "エラー: プログラムの実行に失敗しました。"
        }
    }


    private func loadFiles() {
        guard let directoryURL else { return }
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
            characterCount = countNonWhitespaceCharacters(fileContents)
        } catch {
            if (error as NSError).code != 260 {
                fileContents = "ファイルの読み込みに失敗しました: \(error)"
                characterCount = 0
            }
        }
    }

    private func countNonWhitespaceCharacters(_ content: String) -> Int {
        content.filter {
            !$0.unicodeScalars.allSatisfy {
                CharacterSet.whitespacesAndNewlines.contains($0)
            }
        }
        .count
    }

    private func monitorFileChanges() {
        guard let directoryURL else { return }
        let directoryFileDescriptor = open(directoryURL.path, O_EVTONLY)

        guard directoryFileDescriptor != -1 else {
            print("ディレクトリを監視できませんでした: \(directoryURL.path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: directoryFileDescriptor, eventMask: .all, queue: DispatchQueue.main)

        source.setEventHandler { [weak self] in
            guard let self, let lastLoadedFileURL else { return }
            loadFileContents(selectedFileURL: lastLoadedFileURL)
        }

        source.setCancelHandler {
            print("cancel")
            close(directoryFileDescriptor)
        }

        source.activate()
        self.source = source
    }
}
