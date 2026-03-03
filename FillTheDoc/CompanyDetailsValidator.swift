import Foundation
import DaDataAPIClient

public struct CompanyDetailsValidator: Sendable {
    
    public struct Policy: Sendable {
        public var nameSimilarityThreshold: Double   // Jaccard
        public var addressSimilarityThreshold: Double
        public var warnScoreThreshold: Double
        public var failScoreThreshold: Double
        
        public init(
            nameSimilarityThreshold: Double = 0.72,
            addressSimilarityThreshold: Double = 0.55,
            warnScoreThreshold: Double = 0.75,
            failScoreThreshold: Double = 0.55
        ) {
            self.nameSimilarityThreshold = nameSimilarityThreshold
            self.addressSimilarityThreshold = addressSimilarityThreshold
            self.warnScoreThreshold = warnScoreThreshold
            self.failScoreThreshold = failScoreThreshold
        }
    }
    
    public enum Severity: Sendable { case warning, error }
    
    public struct FieldMessage: Sendable, Equatable {
        public var severity: Severity
        public var text: String
        
        public init(_ severity: Severity, _ text: String) {
            self.severity = severity
            self.text = text
        }
    }
    
    public struct RemoteState: Sendable {
        public var party: DaDataParty?
        
        public init(party: DaDataParty? = nil) {
            self.party = party
        }
    }
    
    private let policy: Policy
    
    public init(policy: Policy = .init()) {
        self.policy = policy
    }
    
    // MARK: - Local (no network) validation for a single field
    
    public func validateLocal(key: String, value raw: String, all: [String: String]) -> FieldMessage? {
        let value = present(raw)
        
        switch key {
            case "inn":
                guard let value else { return nil }
                if !FormatValidators.isValidINN(value) {
                    return .init(.error, "ИНН имеет неверный формат или контрольную сумму.")
                }
                return nil
                
            case "kpp":
                guard let value else { return nil }
                if !FormatValidators.isValidKPP(value) {
                    return .init(.warning, "КПП выглядит некорректно (ожидается 9 цифр).")
                }
                return nil
                
            case "ogrn":
                guard let value else { return nil }
                if !FormatValidators.isValidOGRN(value) {
                    return .init(.warning, "ОГРН/ОГРНИП выглядит некорректно (контрольная сумма/длина).")
                }
                return nil
                
            case "companyName":
                // Обычно локально можно только минимально проверить (не пустое/слишком короткое)
                guard let value else { return nil }
                if value.count < 3 { return .init(.warning, "Название слишком короткое.") }
                return nil
                
            case "ceoFullName":
                guard let value else { return nil }
                if value.count < 5 { return .init(.warning, "ФИО руководителя выглядит слишком коротким.") }
                return nil
                
            case "address":
                guard let value else { return nil }
                if !FormatValidators.looksLikeAddress(value) {
                    return .init(.warning, "Адрес выглядит подозрительно (не похож на адрес).")
                }
                return nil
                
            default:
                return nil
        }
    }
    
    // MARK: - Remote validation on focus lost (may call DaData)
    
    /// Вызывай ТОЛЬКО на blur поля (потеря фокуса).
    /// Возвращает:
    /// - обновлённый RemoteState (кэш party)
    /// - сообщение для конкретного поля (если есть)
    public func validateOnFocusLost(
        all: [String: String],
        remote: RemoteState,
        dadata: DaDataClient
    ) async -> (RemoteState, [String: FieldMessage]) {
        
        // 1) Достаём значения
        let ogrnRaw = present(all["ogrn"])
        let innRaw  = present(all["inn"])
        
        // 2) Выбираем идентификатор для запроса: ОГРН > ИНН
        let query: Query
        if let ogrnRaw, FormatValidators.isValidOGRN(ogrnRaw) {
            query = .ogrn(FormatValidators.digitsOnly(ogrnRaw))
        } else if let innRaw, FormatValidators.isValidINN(innRaw) {
            query = .inn(FormatValidators.digitsOnly(innRaw))
        } else {
            // нет валидного ОГРН/ИНН — это твой явный error
            var msgs: [String: FieldMessage] = [:]
            
            if ogrnRaw?.isEmpty == false, !FormatValidators.isValidOGRN(ogrnRaw!) {
                msgs["ogrn"] = .init(.warning, "ОГРН указан, но формат/контрольная сумма некорректны.")
            }
            if innRaw?.isEmpty == false, !FormatValidators.isValidINN(innRaw!) {
                msgs["inn"] = .init(.warning, "ИНН указан, но формат/контрольная сумма некорректны.")
            }
            
            // ключевая ошибка (можешь повесить на оба поля или на отдельное “form”)
            let root = FieldMessage(.error, "Для проверки по DaData укажите корректный ОГРН или ИНН.")
            msgs["ogrn"] = msgs["ogrn"] ?? root
            msgs["inn"]  = msgs["inn"]  ?? root
            
            return (remote, msgs)
        }
        
        // 3) Запрос к DaData
        var newRemote = remote
        do {
            let party = try await fetchParty(dadata: dadata, query: query)
            newRemote.party = party
        } catch {
            return (newRemote, [
                query.keyForMessage: .init(.warning, "Не удалось проверить по DaData: \(error.localizedDescription)")
            ])
        }
        
        guard let party = newRemote.party else {
            return (newRemote, [
                query.keyForMessage: .init(.warning, "DaData не вернула организацию по указанному идентификатору.")
            ])
        }
        
        // 4) Сверяем ВСЕ поля с ответом DaData
        let messages = crossValidateAll(all: all, party: party)
        return (newRemote, messages)
    }
    
    private enum Query {
        case ogrn(String)
        case inn(String)
        
        var keyForMessage: String {
            switch self {
                case .ogrn: return "ogrn"
                case .inn:  return "inn"
            }
        }
    }
    
    private func crossValidateAll(all: [String: String], party: DaDataParty) -> [String: FieldMessage] {
        let keys = ["ogrn", "inn", "kpp", "companyName", "ceoFullName", "address"]
        var result: [String: FieldMessage] = [:]
        
        for key in keys {
            if let msg = crossValidateField(key: key, all: all, party: party) {
                result[key] = msg
            }
        }
        
        // Дополнительно: статус ACTIVE (не привязан к полю — можешь повесить на companyName или отдельный ключ)
        if let status = party.state?.status, !status.isEmpty, status.uppercased() != "ACTIVE" {
            result["companyName"] = result["companyName"]
            ?? .init(.warning, "Статус организации не ACTIVE (DaData: \(status)).")
        }
        
        return result
    }
    
    // MARK: - Cross validation (field-level) with DaData
    
    private func crossValidateField(key: String, all: [String: String], party: DaDataParty) -> FieldMessage? {
        
        //TODO: use field name from data object
        switch key {
            case "inn":
                guard let llmINN = present(all["inn"]) else { return nil }
                let apiINN = party.inn.map(FormatValidators.digitsOnly)
                if let apiINN, apiINN != FormatValidators.digitsOnly(llmINN) {
                    return .init(.error, "ИНН не совпадает с DaData.")
                }
                return nil
                
            case "kpp":
                guard let llmKPP = present(all["kpp"]) else { return nil }
                if let apiKPP = party.kpp.map(FormatValidators.digitsOnly),
                   apiKPP != FormatValidators.digitsOnly(llmKPP) {
                    return .init(.warning, "КПП не совпадает с DaData.")
                }
                return nil
                
            case "ogrn":
                guard let llmOGRN = present(all["ogrn"]) else { return nil }
                if let apiOGRN = party.ogrn.map(FormatValidators.digitsOnly),
                   apiOGRN != FormatValidators.digitsOnly(llmOGRN) {
                    return .init(.warning, "ОГРН/ОГРНИП не совпадает с DaData.")
                }
                return nil
                
            case "companyName":
                guard let llmName = present(all["companyName"]) else { return nil }
                let apiName =
                party.name?.fullWithOpf
                ?? party.name?.shortWithOpf
                ?? party.name?.full
                ?? party.name?.short
                
                guard let apiName else { return nil }
                
                let sim = TextNormalization.jaccard(llmName, apiName)
                let contains = TextNormalization.containsNormalized(llmName, apiName)
                
                if !(contains || sim >= policy.nameSimilarityThreshold) {
                    return .init(.warning, "Название слабо похоже на DaData (sim=\(String(format: "%.2f", sim))).")
                }
                return nil
                
            case "ceoFullName":
                guard let llmCEO = present(all["ceoFullName"]) else { return nil }
                if let apiCEO = party.management?.name, !apiCEO.isEmpty {
                    let sim = TextNormalization.jaccard(llmCEO, apiCEO)
                    let contains = TextNormalization.containsNormalized(llmCEO, apiCEO)
                    if !(contains || sim >= 0.70) {
                        return .init(.warning, "ФИО руководителя слабо похоже на DaData (sim=\(String(format: "%.2f", sim))).")
                    }
                }
                return nil
                
            case "address":
                guard let llmAddress = present(all["address"]) else { return nil }
                if let apiAddress = party.address?.value, !apiAddress.isEmpty {
                    let sim = TextNormalization.jaccard(llmAddress, apiAddress)
                    let contains = TextNormalization.containsNormalized(llmAddress, apiAddress)
                    
                    if !(contains || sim >= policy.addressSimilarityThreshold) {
                        return .init(.warning, "Адрес слабо похож на DaData (sim=\(String(format: "%.2f", sim))).")
                    }
                }
                return nil
                
            default:
                return nil
        }
    }
    
    // MARK: - DaData query logic
    
    private func shouldQueryDaData(
        changedKey: String,
        inn: String?,
        ogrn: String?,
        name: String?,
        currentParty: DaDataParty?
    ) -> Bool {
        // не спамим сетью: если INN уже найден и не менялся — смысла нет
        if let currentParty, let inn, FormatValidators.digitsOnly(inn) == currentParty.inn {
            // но если changedKey = address/ceo/companyName — можно не дергать DaData повторно,
            // потому что эти данные не улучшают поиск; кросс-проверки и так по текущему party.
            if changedKey != "inn" && changedKey != "ogrn" && changedKey != "kpp" && changedKey != "companyName" {
                return false
            }
        }
        
        // критерии достаточности
        if let inn, FormatValidators.isValidINN(inn) { return true }
        if let ogrn, FormatValidators.isValidOGRN(ogrn) { return true }
        if let name, name.count >= 3 { return true }
        
        return false
    }
    
    private func fetchParty(dadata: DaDataClient, query: Query) async throws -> DaDataParty? {
        switch query {
            case .ogrn(let ogrn):
                return try await dadata.findPartyFirst(innOrOgrn: ogrn)?.data
            case .inn(let inn):
                return try await dadata.findPartyFirst(innOrOgrn: inn)?.data
        }
    }
    
    // MARK: - Helpers
    
    private func present(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
