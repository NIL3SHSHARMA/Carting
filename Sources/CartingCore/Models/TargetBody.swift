//
//  Copyright © 2019 Artem Novichkov. All rights reserved.
//

final class TargetBody {

    let isa: String
    var buildPhases: [BuildPhase]
    let buildConfigurationList: String
    let buildRules: String
    let dependencies: String
    let name: String
    let productName: String
    let productReference: String
    let productType: ProductType

    var description: String {
        var components = [.tripleTab + "isa = \(isa);"]
        components.append(.tripleTab + "buildConfigurationList = \(buildConfigurationList);")
        components.append(.tripleTab + "buildPhases = (")
        buildPhases.forEach { phase in
            components.append(.tripleTab + "\t\(phase.description),")
        }
        components.append(.tripleTab + ");")
        components.append(.tripleTab + "buildRules = \(buildRules);")
        components.append(.tripleTab + "dependencies = \(dependencies);")
        components.append(.tripleTab + "name = \(name);")
        components.append(.tripleTab + "productName = \(productName);")
        components.append(.tripleTab + "productReference = \(productReference);")
        components.append(.tripleTab + "productType = \(productType.description);\n")
        return components.joined(separator: "\n")
    }

    init(isa: String,
         buildPhases: [BuildPhase],
         buildConfigurationList: String,
         buildRules: String,
         dependencies: String,
         name: String,
         productName: String,
         productReference: String,
         productType: ProductType) {
        self.isa = isa
        self.buildPhases = buildPhases
        self.buildConfigurationList = buildConfigurationList
        self.buildRules = buildRules
        self.dependencies = dependencies
        self.name = name
        self.productName = productName
        self.productReference = productReference
        self.productType = productType
    }
}
