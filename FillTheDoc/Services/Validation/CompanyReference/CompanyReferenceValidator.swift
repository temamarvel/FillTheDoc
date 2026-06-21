import Foundation
import DaDataAPIClient

/// Справочная валидация реквизитов компании через DaData/ФНС.
///
/// Это не основной источник истины и не жёсткий gate сценария.
/// Сервис выдаёт в основном warning'и, чтобы помочь пользователю заметить
/// расхождения между извлечёнными/введёнными данными и реестровыми данными.
///
/// Ключевая идея: reference validation помогает оператору принять решение,
/// но не «чинит» данные автоматически. Финальное слово остаётся за человеком.
public actor CompanyReferenceValidator {
    struct Resolution: Sendable {
        let issues: [PlaceholderKey: FieldIssue]
        let referenceValues: [PlaceholderKey: String]
        
        static let empty = Resolution(issues: [:], referenceValues: [:])
    }
    
    public struct Policy: Sendable {
        /// Ниже порога считаем, что название слишком непохоже на реестровое.
        public var nameSimilarityThreshold: Double
        /// Для адресов порог ниже, потому что форматирование адресов обычно менее стабильно.
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
    func validate(values: [PlaceholderKey: String]) async -> [PlaceholderKey: FieldIssue] {
        await resolve(values: values).issues
    }
    
    /// Возвращает both reference-issues и канонические значения из ФНС/DaData,
    /// которые можно безопасно использовать для кнопки автозамены.
    func resolve(values: [PlaceholderKey: String]) async -> Resolution {
        // lookup строится по ОГРН или ИНН — без одного из этих идентификаторов
        // внешняя сверка не имеет смысла.
        let ogrn = values[.ogrn]?.trimmedNilIfEmpty
        let inn = values[.inn]?.trimmedNilIfEmpty
        
        guard let identifier = ogrn ?? inn else { return .empty }
        
        // Кеш нужен, чтобы не выполнять одинаковый сетевой lookup много раз,
        // пока пользователь редактирует другие поля той же компании.
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
            // Network/reference layer здесь intentionally fail-soft:
            // отсутствие сети не должно ломать редактирование формы.
        }
        
        guard let companyInfo else { return .empty }
        let referenceValues = referenceValues(from: companyInfo)
        
        var issues: [PlaceholderKey: FieldIssue] = [:]
        for (key, value) in values {
            if let issue = compareWithReference(
                key: key,
                value: value,
                referenceValues: referenceValues
            ) {
                issues[key] = issue
            }
        }
        return Resolution(issues: issues, referenceValues: referenceValues)
    }
    
    // MARK: - Cross validation with DaData
    
    private func compareWithReference(
        key: PlaceholderKey,
        value: String,
        referenceValues: [PlaceholderKey: String]
    ) -> FieldIssue? {
        // Здесь проверяются только те поля, для которых у нас есть meaningful external reference.
        // Для остальных либо нет надёжного источника, либо такая сверка не даёт практической пользы.
        switch key {
            case .inn:
                let apiINN = referenceValues[.inn].map { $0.digitsOnly }
                if let apiINN, apiINN != value.digitsOnly {
                    return .warning("ИНН не совпадает с ФНС.")
                }
                return nil
                
            case .kpp:
                if let apiKPP = referenceValues[.kpp].map({ $0.digitsOnly }),
                   apiKPP != value.digitsOnly {
                    return .warning("КПП не совпадает с ФНС.")
                }
                return nil
                
            case .ogrn:
                if let apiOGRN = referenceValues[.ogrn].map({ $0.digitsOnly }),
                   apiOGRN != value.digitsOnly {
                    return .warning("ОГРН/ОГРНИП не совпадает с ФНС.")
                }
                return nil
                
            case .legalForm:
                guard let apiLegalForm = referenceValues[.legalForm]?.trimmedNilIfEmpty else {
                    return nil
                }
                
                if canonicalLegalForm(value) != canonicalLegalForm(apiLegalForm) {
                    return .warning("Правовая форма не совпадает с ФНС.")
                }
                return nil
                
            case .companyName:
                let apiName = referenceValues[.companyName]
                guard let apiName else { return nil }
                
                if isReferenceMatch(value, apiName) {
                    return nil
                }
                
                let sim = Validators.jaccardSimilarity(value, apiName)
                let contains = Validators.containsNormalized(value, apiName)
                if !(contains || sim >= policy.nameSimilarityThreshold) {
                    return .warning("Название не совпадает с ФНС (схожесть: \(String(format: "%.2f", sim))).")
                }
                return nil
                
            case .ceoFullName:
                if let apiCEO = referenceValues[.ceoFullName], !apiCEO.isEmpty {
                    if isReferenceMatch(value, apiCEO) {
                        return nil
                    }
                    
                    let sim = Validators.jaccardSimilarity(value, apiCEO)
                    let contains = Validators.containsNormalized(value, apiCEO)
                    if !(contains || sim >= policy.nameSimilarityThreshold) {
                        return .warning("ФИО руководителя не совпадает с ФНС (схожесть: \(String(format: "%.2f", sim))).")
                    }
                }
                return nil
                
            case .address:
                if let apiAddress = referenceValues[.address], !apiAddress.isEmpty {
                    if isReferenceMatch(value, apiAddress) {
                        return nil
                    }
                    
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
    
    private func referenceValues(from companyInfo: DaDataCompanyInfo) -> [PlaceholderKey: String] {
        var values: [PlaceholderKey: String] = [:]
        
        if let inn = companyInfo.inn?.digitsOnly.trimmedNilIfEmpty {
            values[.inn] = inn
        }
        
        if let kpp = companyInfo.kpp?.digitsOnly.trimmedNilIfEmpty {
            values[.kpp] = kpp
        }
        
        if let ogrn = companyInfo.ogrn?.digitsOnly.trimmedNilIfEmpty {
            values[.ogrn] = ogrn
        }
        
        if let legalForm = referenceLegalForm(from: companyInfo)?.shortName {
            values[.legalForm] = legalForm
        }
        
        if let companyName = referenceCompanyName(from: companyInfo) {
            values[.companyName] = companyName
        }
        
        if let ceoName = companyInfo.management?.name?.trimmedNilIfEmpty {
            values[.ceoFullName] = ceoName
        }
        
        if let address = companyInfo.address?.unrestrictedValue?.trimmedNilIfEmpty
            ?? companyInfo.address?.value?.trimmedNilIfEmpty {
            values[.address] = address
        }
        
        return values
    }
}

private extension CompanyReferenceValidator {
    func referenceCompanyName(from companyInfo: DaDataCompanyInfo) -> String? {
        let legalForm = referenceLegalForm(from: companyInfo)
        let name = companyInfo.name
        let candidates = [
            name?.short,
            name?.full,
            name?.shortWithOpf,
            name?.fullWithOpf
        ]
        
        for candidate in candidates {
            guard let candidate = candidate?.trimmedNilIfEmpty else { continue }
            let stripped = stripLegalFormIfNeeded(from: candidate, legalForm: legalForm)
            if let normalized = sanitizeCompanyName(stripped) {
                return normalized
            }
        }
        
        return nil
    }
    
    func referenceLegalForm(from companyInfo: DaDataCompanyInfo) -> LegalForm? {
        let name = companyInfo.name
        let candidates = [
            name?.shortWithOpf,
            name?.fullWithOpf,
            name?.short,
            name?.full
        ]
        
        for candidate in candidates {
            guard let candidate = candidate?.trimmedNilIfEmpty else { continue }
            if let legalForm = detectLegalForm(in: candidate) {
                return legalForm
            }
        }
        
        if companyInfo.type?.uppercased() == "INDIVIDUAL" {
            return .ip
        }
        
        return nil
    }
    
    func detectLegalForm(in value: String) -> LegalForm? {
        let candidates = LegalForm.allCases
            .sorted { $0.fullName.count > $1.fullName.count }
        
        for legalForm in candidates {
            let prefixes = [legalForm.shortName, legalForm.fullName]
            for prefix in prefixes {
                if hasPrefix(prefix, in: value) {
                    return legalForm
                }
            }
        }
        
        return nil
    }
    
    func stripLegalFormIfNeeded(from value: String, legalForm: LegalForm?) -> String {
        guard let legalForm else {
            return value
        }
        
        let prefixes = [legalForm.fullName, legalForm.shortName]
            .sorted { $0.count > $1.count }
        
        for prefix in prefixes where hasPrefix(prefix, in: value) {
            return String(value.dropFirst(prefix.count)).trimmed
        }
        
        return value
    }
    
    func hasPrefix(_ prefix: String, in value: String) -> Bool {
        let normalizedValue = Normalizers.legalForm(value)
        let normalizedPrefix = Normalizers.legalForm(prefix)
        return normalizedValue == normalizedPrefix
        || normalizedValue.hasPrefix(normalizedPrefix + " ")
    }
    
    func sanitizeCompanyName(_ value: String) -> String? {
        let trimmed = value.trimmed
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'«»„“”`“”"))
            .trimmed
        return trimmed.isEmpty ? nil : trimmed
    }
    
    func canonicalLegalForm(_ value: String) -> String {
        if let parsed = LegalForm.parse(value) {
            return parsed.shortName
        }
        return Normalizers.legalForm(value)
    }
    
    func isReferenceMatch(_ value: String, _ referenceValue: String) -> Bool {
        Normalizers.forComparison(value) == Normalizers.forComparison(referenceValue)
    }
}
