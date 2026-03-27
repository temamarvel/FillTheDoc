import Foundation
import DaDataAPIClient

public struct FieldState: Sendable, Equatable {
    var value : String?
    var message: CompanyDetailsValidator.FieldMessage?
    var isValid: Bool {
        message == nil
    }
}

@MainActor
public final class CompanyDetailsValidator {
    
    public typealias Key = CompanyDetails.CodingKeys
    
    public struct Policy: Sendable {
        public var nameSimilarityThreshold: Double   // Jaccard
        public var addressSimilarityThreshold: Double
        
        public var preferRemoteOnTie: Bool
        public var combineTextsOnTie: Bool
        
        public init(
            nameSimilarityThreshold: Double = 0.72,
            addressSimilarityThreshold: Double = 0.55,
            preferRemoteOnTie: Bool = false,
            combineTextsOnTie: Bool = true
        ) {
            self.nameSimilarityThreshold = nameSimilarityThreshold
            self.addressSimilarityThreshold = addressSimilarityThreshold
            self.preferRemoteOnTie = preferRemoteOnTie
            self.combineTextsOnTie = combineTextsOnTie
        }
    }
    
    public enum Severity: Int, Sendable, Comparable {
        case warning = 0
        case error = 1
        
        public static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    public struct FieldMessage: Sendable, Equatable {
        public var severity: Severity? {
            if error != nil {
                return .error
            }
            if warning != nil {
                return .warning
            }
            return nil
        }
        public var text: String? { error ?? warning }
        public var error: String?
        public var warning: String?
    }
    
    private let policy: Policy
    private let dadataClient: DaDataClient
    private var cache: [String: DaDataCompanyInfo] //TODO maybe not good to use String as key
    
    public init(dadataClient: DaDataClient, policy: Policy = .init()) {
        self.policy = policy
        self.dadataClient = dadataClient
        self.cache = [:]
    }
    
    // MARK: - Local validation (no network)
    
    public func validateField(for fieldKey: Key, state: FieldState) -> FieldMessage? {
        guard let validator = CompanyDetails.fieldMetadata[fieldKey]?.validator else {
            return nil // TODO: подумать если нет валидатора то это ошибка или нет?  ведь валидации-то не было
        }
        
        guard let value = state.value else {
            return nil // TODO: подумать если нет значения то это ошибка или нет? и вообще как сюда может придти что-то без значения?
        }
        
        let validationResult = validator(value)
        
        //TODO FieldMessage same logic as ValidationResult
        return validationResult.state == .pass ? nil : FieldMessage(error: validationResult.text, warning: nil)
    }
    
    public func validateFieldsWithReference(fields: [Key: FieldState]) async -> [Key: FieldState] {
        //fields have to be normalized and not null before validation
        
        let ogrn = fields[.ogrn]?.value
        let inn = fields[.inn]?.value
        
        // MARK: get dadata company info
        var dadataCompanyInfo: DaDataCompanyInfo? = nil
        do{
            let identifier = ogrn ?? inn
            
            guard let identifier else {
                return fields
            }
            
            if let cached = cache[identifier] {
                dadataCompanyInfo = cached
            } else {
                dadataCompanyInfo = try await dadataClient.fetchCompanyInfoFirts(innOrOgrn: identifier)?.data
                if let dadataCompanyInfo {
                    if let fetchedOgrn = dadataCompanyInfo.ogrn {
                        cache[fetchedOgrn] = dadataCompanyInfo
                    }
                    if let fetchedInn = dadataCompanyInfo.inn {
                        cache[fetchedInn] = dadataCompanyInfo
                    }
                }
            }
        }
        catch{
            
        }
        
        guard let dadataCompanyInfo else {
            return fields //TODO
        }
        
        // MARK: validate all fields using dadata info
        
        var resultFields = fields
        
        for (key, state) in fields {
            let msg = crossValidateField(fieldKey: key, state: state, companyInfo: dadataCompanyInfo)
            
            guard let msg else { continue }
            
            if resultFields[key]?.message == nil {
                resultFields[key]?.message = msg
            }
            else {
                resultFields[key]?.message?.warning = msg.warning
            }
        }
        
        return resultFields
    }
    
    // MARK: - Cross validation with DaData
    
    private func crossValidateField(fieldKey: Key, state: FieldState, companyInfo: DaDataCompanyInfo) -> FieldMessage? {
        switch fieldKey {
            case .inn:
                guard let llmINN = state.value else { return nil }
                let apiINN = companyInfo.inn.map { $0.digitsOnly }
                if let apiINN, apiINN != llmINN.digitsOnly {
                    return FieldMessage(error: nil, warning: "ИНН не совпадает с DaData.")
                }
                return nil
                
            case .kpp:
                guard let llmKPP = state.value else { return nil }
                if let apiKPP = companyInfo.kpp.map({ $0.digitsOnly }),
                   apiKPP != llmKPP.digitsOnly {
                    return FieldMessage(error: nil, warning: "КПП не совпадает с DaData.")
                }
                return nil
                
            case .ogrn:
                guard let llmOGRN = state.value else { return nil }
                if let apiOGRN = companyInfo.ogrn.map({ $0.digitsOnly }),
                   apiOGRN != llmOGRN.digitsOnly {
                    return FieldMessage(error: nil, warning: "ОГРН/ОГРНИП не совпадает с DaData.")
                }
                return nil
                
            case .companyName:
                guard let llmName = state.value else { return nil }
                
                let apiName =
                companyInfo.name?.fullWithOpf
                ?? companyInfo.name?.shortWithOpf
                ?? companyInfo.name?.full
                ?? companyInfo.name?.short
                
                guard let apiName else { return nil }
                
                let sim = Validators.jaccardSimilarity(llmName, apiName)
                let contains = Validators.containsNormalized(llmName, apiName)
                
                if !(contains || sim >= policy.nameSimilarityThreshold) {
                    return FieldMessage(error: nil, warning: "Название слабо похоже на DaData (sim=\(String(format: "%.2f", sim))).")
                }
                return nil
                
            case .ceoFullName:
                guard let llmCEO = state.value else { return nil }
                if let apiCEO = companyInfo.management?.name, !apiCEO.isEmpty {
                    let sim = Validators.jaccardSimilarity(llmCEO, apiCEO)
                    let contains = Validators.containsNormalized(llmCEO, apiCEO)
                    if !(contains || sim >= 0.70) {
                        return FieldMessage(error: nil, warning: "ФИО руководителя слабо похоже на DaData (sim=\(String(format: "%.2f", sim))).")
                    }
                }
                return nil
                
                // сейчас не кросс-валидируем
            case .legalForm, .ceoShortenName, .email, .phone:
                return nil
                // TODO: address
            case .address:
                guard let llmAddress = state.value else { return nil }
                
                if let apiAddress = companyInfo.address?.value, !apiAddress.isEmpty {
                    let sim = Validators.jaccardSimilarity(llmAddress, apiAddress)
                    let contains = Validators.containsNormalized(llmAddress, apiAddress)
                    if !(contains || sim >= 0.70) {
                        return FieldMessage(error: nil, warning: "Адрес слабо похож на DaData \(apiAddress) (sim=\(String(format: "%.2f", sim))).")
                    }
                }
                
                return nil
        }
    }
}
