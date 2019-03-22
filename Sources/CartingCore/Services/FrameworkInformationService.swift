//
//  Copyright © 2017 Rosberry. All rights reserved.
//

import Files
import ShellOut
import Foundation

final class FrameworkInformationService {

    private enum Keys {
        static let carthageScript = "\"/usr/local/bin/carthage copy-frameworks\""
    }

    var path: String?

    private var projectFolder: Folder {
        if let path = path, let folder = try? Folder(path: path) {
            return folder
        }
        return FileSystem().currentFolder
    }

    private lazy var projectService: ProjectService = .init()

    // MARK: - Lifecycle

    func updateScript(withName scriptName: String, path: String?, format: Arguments.Format) throws {
        let project = try projectService.project(path)

        var projectHasBeenUpdated = false

        try project.targets
            .filter { $0.body.productType.isApplication }
            .forEach { target in
            let frameworkBuildPhase = target.body.buildPhases.first { $0.name == "Frameworks" }
            let frameworkScript = project.frameworkScripts.first { $0.identifier == frameworkBuildPhase?.identifier }
            guard let script = frameworkScript else {
                return
            }
            let linkedCarthageDynamicFrameworkNames = try frameworksInformation()
                .filter { information in
                    information.linking == .dynamic && script.body.files.contains { $0.name == information.name }
                }
                .map { $0.name }

            let inputPaths = projectService.paths(forFrameworkNames: linkedCarthageDynamicFrameworkNames,
                                                  type: .input)
            let outputPaths = projectService.paths(forFrameworkNames: linkedCarthageDynamicFrameworkNames,
                                                   type: .output)

            let carthageFolder = try projectFolder.subfolder(named: "Carthage")
            let listFolder = try carthageFolder.createSubfolderIfNeeded(withName: "xcfilelists")
            let parent = carthageFolder.parent ?? projectFolder
            let path = listFolder.path.replacingOccurrences(of: parent.path, with: "$(SRCROOT)/").deleting(suffix: "/")

            let inputFileList = try listFolder.createFileIfNeeded(withName: "\(target.name)-inputPaths.xcfilelist")
            try inputFileList.write(string: inputPaths.joined(separator: "\n"))
            let inputFileListPath = [path, inputFileList.name].joined(separator: "/")

            let outputFileList = try listFolder.createFileIfNeeded(withName: "\(target.name)-outputPaths.xcfilelist")
            try outputFileList.write(string: outputPaths.joined(separator: "\n"))
            let outputFileListPath = [path, outputFileList.name].joined(separator: "/")

            let carthageBuildPhase = target.body.buildPhases.first { $0.name == scriptName }
            let carthageScript = project.scripts.first { $0.identifier == carthageBuildPhase?.identifier }

            if let carthage = carthageScript {
                var scriptHasBeenUpdated = false

                switch format {
                case .file:
                    if carthage.body.inputFileListPaths?.isEmpty == false {
                        carthage.body.inputFileListPaths?.removeAll()
                        scriptHasBeenUpdated = true
                    }
                    if carthage.body.inputPaths != inputPaths {
                        carthage.body.inputPaths = inputPaths
                        scriptHasBeenUpdated = true
                    }
                    if carthage.body.outputFileListPaths?.isEmpty == false {
                        carthage.body.outputFileListPaths?.removeAll()
                        scriptHasBeenUpdated = true
                    }
                    if carthage.body.outputPaths != outputPaths {
                        carthage.body.outputPaths = outputPaths
                        scriptHasBeenUpdated = true
                    }
                    if carthage.body.shellScript != Keys.carthageScript {
                        carthage.body.shellScript = Keys.carthageScript
                        scriptHasBeenUpdated = true
                    }
                case .list:
                    if !carthage.body.inputPaths.isEmpty {
                        carthage.body.inputPaths.removeAll()
                        scriptHasBeenUpdated = true
                    }
                    if carthage.body.inputFileListPaths?.first != inputFileListPath {
                        carthage.body.inputFileListPaths = [inputFileListPath]
                        scriptHasBeenUpdated = true
                    }
                    if carthage.body.outputFileListPaths?.first != outputFileListPath {
                        carthage.body.outputFileListPaths = [outputFileListPath]
                        scriptHasBeenUpdated = true
                    }
                    if !carthage.body.outputPaths.isEmpty {
                        carthage.body.outputPaths.removeAll()
                        scriptHasBeenUpdated = true
                    }
                    if carthage.body.shellScript != Keys.carthageScript {
                        carthage.body.shellScript = Keys.carthageScript
                        scriptHasBeenUpdated = true
                    }
                }
                if scriptHasBeenUpdated {
                    projectHasBeenUpdated = true
                    print("✅ Script \(scriptName) in target \(target.name) was successfully updated.")
                }
            }
            else {
                let body: ScriptBody
                switch format {
                case .file:
                    body = ScriptBody(inputPaths: inputPaths,
                                      name: scriptName,
                                      outputPaths: outputPaths,
                                      shellScript: Keys.carthageScript)
                case .list:
                    body = ScriptBody(inputFileListPaths: [inputFileListPath],
                                      name: scriptName,
                                      outputFileListPaths: [outputFileListPath],
                                      shellScript: Keys.carthageScript)
                }

                let identifier = String.randomAlphaNumericString(length: 24)
                let script = Script(identifier: identifier, name: scriptName, body: body)
                let buildPhase = BuildPhase(identifier: identifier, name: scriptName)
                project.scripts.append(script)
                target.body.buildPhases.append(buildPhase)
                print("✅ Script \(scriptName) was successfully added to \(target.name) target.")
                projectHasBeenUpdated = true
            }
        }

        if projectHasBeenUpdated {
            try projectService.update(project)
        }
        else {
            print("🤷‍♂️ Nothing to update.")
        }
    }

    func frameworksInformation() throws -> [FrameworkInformation] {
        let frameworkFolder = try projectFolder.subfolder(atPath: "Carthage/Build/iOS")
        let frameworks = frameworkFolder.subfolders.filter { $0.name.hasSuffix("framework") }
        return try frameworks.map(information)
    }

    func printFrameworksInformation() throws {
        let informations = try frameworksInformation()
        informations.forEach { information in
            let description = [information.name, information.linking.rawValue].joined(separator: "\t\t") +
                "\t" +
                information.architectures.map { $0.rawValue }.joined(separator: ", ")
            print(description)
        }
    }

    // MARK: - Private

    private func information(for framework: Folder) throws -> FrameworkInformation {
        let path = framework.path + framework.nameExcludingExtension
        let fileOutput = try shellOut(to: "file", arguments: [path.quotify])
        let lipoOutput = try shellOut(to: "lipo", arguments: ["-info", path.quotify])
        let rawArchitectures = lipoOutput.components(separatedBy: ": ").last!
        return FrameworkInformation(name: framework.name,
                                    architectures: architectures(fromOutput: rawArchitectures),
                                    linking: linking(fromOutput: fileOutput))
    }
}

func getEnvironmentVar(_ name: String) -> String? {
    guard let rawValue = getenv(name) else {
        return nil
    }
    return String(utf8String: rawValue)
}

struct FrameworkInformation {

    enum Architecture: String {
        case i386, x86_64, armv7, arm64
    }

    enum Linking: String {
        case `static`, dynamic
    }

    let name: String
    let architectures: [Architecture]
    let linking: Linking
}

func linking(fromOutput output: String) -> FrameworkInformation.Linking {
    if output.contains("current ar archive") {
        return .static
    }
    return .dynamic
}

func architectures(fromOutput output: String) -> [FrameworkInformation.Architecture] {
    return output.components(separatedBy: " ").compactMap(FrameworkInformation.Architecture.init)
}
