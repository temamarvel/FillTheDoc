import Foundation
import DaDataAPIClient

/// Справочная валидация company-реквизитов через DaData/ФНС.
///
/// Это не основной источник истины и не жёсткий gate сценария.
/// Сервис выдаёт в основном warning'и, чтобы помочь пользователю заметить
/// расхождения между извлечёнными/введёнными данными и реестровыми данными.
public actor CompanyDetailsValidator {
    
    public struct Policy: Sendable {
        public var nameSimilarityThreshold: Double
        public var addressSimilarityThreshold: Double
        
        public init(
            nameSimilarityThreshold: Double = 0.72,
            addressSimilarityThreshold: Double = 0.55
        ) {
            self.nameSimilarityThreshold = nameSimilarityThreshold
            self.addressSimilarityThreshold = addressSimilarityThreshold
        }
    }
    
    private let policy: Policy
    private let dadataClient: DaDataClient
    private var cache: [String: DaDataCompanyInfo]
    
    init(policy: Policy = .init()) {
        let token = Bundle.main.infoDictionary?["DADATA_TOKEN"] as? String ?? "N_T"
        self.policy = policy
        self.dadataClient = DaDataClient(configuration: .init(token: token))
        self.cache = [:]
    }
    
    // MARK: - Reference validation
    
    /// Принимает текущие значения полей, возвращает найденные issues от DaData.
    func validateWithReference(values: [PlaceholderKey: String]) async -> [PlaceholderKey: FieldIssue] {
        // lookup строится по ОГРН или ИНН — без одного из этих идентификаторов
        // внешняя сверка не имеет смысла.
        let ogrn = values[PlaceholderKey(rawValue: "ogrn")]?.trimmedNilIfEmpty
        let inn = values[PlaceholderKey(rawValue: "inn")]?.trimmedNilIfEmpty
        
        guard let identifier = ogrn ?? inn else { return [:] }
        
        // Fetch or use cache
        var companyInfo: DaDataCompanyInfo?
        do {
            if let cached = cache[identifier] {
                companyInfo = cached
            } else {
                companyInfo = try await dadataClient.fetchCompanyInfoFirts(innOrOgrn: identifier)?.data
                if let companyInfo {
                    if let fetchedOgrn = companyInfo.ogrn { cache[fetchedOgrn] = companyInfo }
                    if let fetchedInn = companyInfo.inn { cache[fetchedInn] = companyInfo }
                }
            }
        } catch {
            // network error — skip
        }
        
        guard let companyInfo else { return [:] }
        
        var issues: [PlaceholderKey: FieldIssue] = [:]
        for (key, value) in values {
            if let issue = crossValidate(key: key, value: value, companyInfo: companyInfo) {
                issues[key] = issue
            }
        }
        return issues
    }
    
    // MARK: - Cross validation with DaData
    
    private func crossValidate(key: PlaceholderKey, value: String, companyInfo: DaDataCompanyInfo) -> FieldIssue? {
        switch key.rawValue {
            case "inn":
                let apiINN = companyInfo.inn.map { $0.digitsOnly }
                if let apiINN, apiINN != value.digitsOnly {
                    return .warning("ИНН не совпадает с ФНС.")
                }
                return nil
                
            case "kpp":
                if let apiKPP = companyInfo.kpp.map({ $0.digitsOnly }),
                   apiKPP != value.digitsOnly {
                    return .warning("КПП не совпадает с ФНС.")
                }
                return nil
                
            case "ogrn":
                if let apiOGRN = companyInfo.ogrn.map({ $0.digitsOnly }),
                   apiOGRN != value.digitsOnly {
                    return .warning("ОГРН/ОГРНИП не совпадает с ФНС.")
                }
                return nil
                
            case "company_name":
                let apiName =
                companyInfo.name?.fullWithOpf
                ?? companyInfo.name?.shortWithOpf
                ?? companyInfo.name?.full
                ?? companyInfo.name?.short
                guard let apiName else { return nil }
                
                let sim = Validators.jaccardSimilarity(value, apiName)
                let contains = Validators.containsNormalized(value, apiName)
                if !(contains || sim >= policy.nameSimilarityThreshold) {
                    return .warning("Название не совпадает с ФНС (схожесть: \(String(format: "%.2f", sim))).")
                }
                return nil
                
            case "ceo_full_name":
                if let apiCEO = companyInfo.management?.name, !apiCEO.isEmpty {
                    let sim = Validators.jaccardSimilarity(value, apiCEO)
                    let contains = Validators.containsNormalized(value, apiCEO)
                    if !(contains || sim >= policy.nameSimilarityThreshold) {
                        return .warning("ФИО руководителя не совпадает с ФНС (схожесть: \(String(format: "%.2f", sim))).")
                    }
                }
                return nil
                
            case "address":
                if let apiAddress = companyInfo.address?.value, !apiAddress.isEmpty {
                    let sim = Validators.jaccardSimilarity(value, apiAddress)
                    let contains = Validators.containsNormalized(value, apiAddress)
                    if !(contains || sim >= policy.addressSimilarityThreshold) {
                        return .warning("Адрес не совпадает с ФНС \(apiAddress) (схожесть: \(String(format: "%.2f", sim))).")
                    }
                }
                return nil
                
            default:
                return nil
        }
    }
}
