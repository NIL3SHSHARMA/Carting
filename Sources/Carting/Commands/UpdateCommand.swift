//
//  Copyright © 2019 Artem Novichkov. All rights reserved.
//

import SPMUtility
import CartingCore
import Foundation

final class UpdateCommand: Command {

    var command = "update"
    var overview = "Adds a new script with input/output file paths or updates the script named `Carthage`."

    private let name: OptionArgument<String>
    private let projectDirectoryPath: OptionArgument<String>
    private let format: OptionArgument<Format>
    private let targetName: OptionArgument<String>
    private let projectNames: OptionArgument<[String]>

    required init(parser: ArgumentParser) {
        let subparser = parser.add(subparser: command, overview: overview)
        name = subparser.add(option: "--script",
                             shortName: "-s",
                             usage: "The name of Carthage script.")
        projectDirectoryPath = subparser.add(option: "--path",
                                    shortName: "-p",
                                    usage: "The project directory path.",
                                    completion: .filename)
        format = subparser.add(option: "--format",
                               shortName: "-f",
                               usage: "Format of input/output file paths: file - using simple paths, list - using xcfilelists",
                               completion: Format.completion)
        targetName = subparser.add(option: "--target",
                                   shortName: "-t",
                                   usage: "The name of target.")
        projectNames = subparser.add(option: "--project-names",
                                     shortName: "-n",
                                     usage: "The names of projects.")
    }

    func run(with arguments: ArgumentParser.Result) throws {
        let name = arguments.get(self.name) ?? "Carthage"
        let projectDirectoryPath = arguments.get(self.projectDirectoryPath) ?? ProcessInfo.processInfo.environment["PROJECT_DIR"]
        let format = arguments.get(self.format) ?? .list
        let targetName = arguments.get(self.targetName) ?? ProcessInfo.processInfo.environment["TARGET_NAME"]
        let projectNames = arguments.get(self.projectNames) ?? []
        let projectService = try ProjectService(projectDirectoryPath: projectDirectoryPath)
        try projectService.updateScript(withName: name,
                                        format: format,
                                        targetName: targetName,
                                        projectNames: projectNames)
    }
}
