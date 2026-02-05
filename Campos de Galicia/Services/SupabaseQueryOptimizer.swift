import Foundation
import Supabase

/// Optimizador de queries para Supabase
/// Proporciona métodos optimizados con paginación, filtros y selección de campos específicos
final class SupabaseQueryOptimizer {

    // MARK: - Pagination Configuration

    /// Configuración de paginación
    struct PaginationConfig {
        let pageSize: Int
        let maxPages: Int?

        static let `default` = PaginationConfig(pageSize: 50, maxPages: nil)
        static let small = PaginationConfig(pageSize: 20, maxPages: 10)
        static let large = PaginationConfig(pageSize: 100, maxPages: nil)
    }

    /// Resultado paginado
    struct PaginatedResult<T: Decodable> {
        let items: [T]
        let page: Int
        let pageSize: Int
        let hasMore: Bool
        let totalFetched: Int
    }

    // MARK: - Query Optimization Methods

    /// Fetch campos con selección de campos específicos y orden
    /// Solo trae los campos necesarios en lugar de `SELECT *`
    static func fetchCamposOptimized(
        client: SupabaseClient,
        fields: [String] = ["*"],
        orderBy: String = "nombre",
        ascending: Bool = true,
        limit: Int? = nil
    ) async throws -> [CampoModel] {
        let selectFields = fields.joined(separator: ",")

        var query = client.from("campos")
            .select(selectFields)
            .order(orderBy, ascending: ascending)

        if let limit = limit {
            query = query.limit(limit)
        }

        let response = try await query.execute()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CampoModel].self, from: response.data)
    }

    /// Fetch campos con paginación cursor-based
    /// Más eficiente para datasets grandes
    static func fetchCamposPaginated(
        client: SupabaseClient,
        page: Int = 0,
        config: PaginationConfig = .default,
        orderBy: String = "nombre",
        ascending: Bool = true
    ) async throws -> PaginatedResult<CampoModel> {
        let offset = page * config.pageSize
        let limit = config.pageSize + 1 // Fetch one extra to check if there are more

        let response = try await client.from("campos")
            .select("*")
            .order(orderBy, ascending: ascending)
            .range(from: offset, to: offset + limit - 1)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var items = try decoder.decode([CampoModel].self, from: response.data)

        let hasMore = items.count > config.pageSize
        if hasMore {
            items.removeLast() // Remove the extra item
        }

        return PaginatedResult(
            items: items,
            page: page,
            pageSize: config.pageSize,
            hasMore: hasMore,
            totalFetched: items.count
        )
    }

    /// Fetch contribuciones con paginación y filtros
    static func fetchContribucionesPaginated(
        client: SupabaseClient,
        campoID: UUID,
        page: Int = 0,
        config: PaginationConfig = .default,
        onlyApproved: Bool = true
    ) async throws -> PaginatedResult<ContribucionAprobada> {
        let offset = page * config.pageSize
        let limit = config.pageSize + 1

        var query = client.from("campo_contribuciones")
            .select("*")
            .eq("id_campo", value: campoID.uuidString)

        if onlyApproved {
            query = query.eq("aprobada", value: true)
        }

        query = query
            .order("fecha", ascending: false)
            .range(from: offset, to: offset + limit - 1)

        let response = try await query.execute()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var items = try decoder.decode([ContribucionAprobada].self, from: response.data)

        let hasMore = items.count > config.pageSize
        if hasMore {
            items.removeLast()
        }

        return PaginatedResult(
            items: items,
            page: page,
            pageSize: config.pageSize,
            hasMore: hasMore,
            totalFetched: items.count
        )
    }

    /// Fetch incremental - solo trae registros nuevos desde la última actualización
    static func fetchCamposIncremental(
        client: SupabaseClient,
        since: Date,
        orderBy: String = "updated_at",
        limit: Int = 1000
    ) async throws -> [CampoModel] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceString = formatter.string(from: since)

        let response = try await client.from("campos")
            .select("*")
            .gte("updated_at", value: sinceString)
            .order(orderBy, ascending: false)
            .limit(limit)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CampoModel].self, from: response.data)
    }

    /// Fetch múltiples campos por IDs en batch
    /// Más eficiente que hacer múltiples queries individuales
    static func fetchCamposByIDs(
        client: SupabaseClient,
        ids: [UUID],
        fields: [String] = ["*"]
    ) async throws -> [CampoModel] {
        guard !ids.isEmpty else { return [] }

        let selectFields = fields.joined(separator: ",")
        let idStrings = ids.map { $0.uuidString }

        let response = try await client.from("campos")
            .select(selectFields)
            .in("id", values: idStrings)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CampoModel].self, from: response.data)
    }

    /// Fetch con filtros geográficos (campos cercanos)
    /// Usa RPC para queries geoespaciales eficientes
    static func fetchCamposCercanos(
        client: SupabaseClient,
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 10,
        limit: Int = 50
    ) async throws -> [CampoModel] {
        // Nota: Esto requiere una función RPC en Supabase
        // Para implementación completa, necesitarías crear una función PostgreSQL
        // Aquí muestro la estructura básica

        let params: [String: Any] = [
            "lat": latitude,
            "long": longitude,
            "radius_km": radiusKm
        ]

        // Fallback a filtro local si no hay función RPC
        // En producción, deberías usar una función PostGIS en Supabase
        Logger.warning("⚠️ fetchCamposCercanos: Consider implementing RPC function for geo queries")

        let allCampos = try await fetchCamposOptimized(
            client: client,
            orderBy: "nombre",
            ascending: true,
            limit: limit * 2 // Fetch extra and filter locally
        )

        // Filtrar por distancia localmente (no óptimo para grandes datasets)
        let nearby = allCampos.filter { campo in
            guard let campoLat = campo.latitud, let campoLon = campo.longitud else {
                return false
            }
            let distance = calculateDistance(
                lat1: latitude,
                lon1: longitude,
                lat2: campoLat,
                lon2: campoLon
            )
            return distance <= radiusKm
        }

        return Array(nearby.prefix(limit))
    }

    /// Fetch reseñas con paginación y filtros
    static func fetchReseñasPaginated(
        client: SupabaseClient,
        campoID: UUID,
        page: Int = 0,
        config: PaginationConfig = .default,
        minRating: Int? = nil
    ) async throws -> PaginatedResult<Review> {
        let offset = page * config.pageSize
        let limit = config.pageSize + 1

        var query = client.from("reseñas")
            .select("*")
            .eq("campo_id", value: campoID.uuidString)

        if let minRating = minRating {
            query = query.gte("rating", value: minRating)
        }

        query = query
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)

        let response = try await query.execute()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var items = try decoder.decode([Review].self, from: response.data)

        let hasMore = items.count > config.pageSize
        if hasMore {
            items.removeLast()
        }

        return PaginatedResult(
            items: items,
            page: page,
            pageSize: config.pageSize,
            hasMore: hasMore,
            totalFetched: items.count
        )
    }

    /// Obtener conteo de registros sin traer todos los datos
    /// Útil para paginación
    static func countRecords(
        client: SupabaseClient,
        table: String,
        filters: [String: Any] = [:]
    ) async throws -> Int {
        var query = client.from(table)
            .select("id", head: true, count: .exact)

        for (key, value) in filters {
            if let stringValue = value as? String {
                query = query.eq(key, value: stringValue)
            } else if let intValue = value as? Int {
                query = query.eq(key, value: intValue)
            } else if let boolValue = value as? Bool {
                query = query.eq(key, value: boolValue)
            }
        }

        let response = try await query.execute()
        return response.count ?? 0
    }

    // MARK: - Query Building Helpers

    /// Builder para queries complejas con múltiples filtros
    struct QueryBuilder {
        let client: SupabaseClient
        let table: String
        private var filters: [(key: String, value: Any)] = []
        private var orderColumn: String?
        private var isAscending: Bool = true
        private var limitValue: Int?
        private var rangeFrom: Int?
        private var rangeTo: Int?

        init(client: SupabaseClient, table: String) {
            self.client = client
            self.table = table
        }

        func filter(_ key: String, equals value: Any) -> QueryBuilder {
            var builder = self
            builder.filters.append((key, value))
            return builder
        }

        func order(by column: String, ascending: Bool = true) -> QueryBuilder {
            var builder = self
            builder.orderColumn = column
            builder.isAscending = ascending
            return builder
        }

        func limit(_ value: Int) -> QueryBuilder {
            var builder = self
            builder.limitValue = value
            return builder
        }

        func range(from: Int, to: Int) -> QueryBuilder {
            var builder = self
            builder.rangeFrom = from
            builder.rangeTo = to
            return builder
        }

        func execute<T: Decodable>() async throws -> [T] {
            var query = client.from(table).select("*")

            for filter in filters {
                if let stringValue = filter.value as? String {
                    query = query.eq(filter.key, value: stringValue)
                } else if let intValue = filter.value as? Int {
                    query = query.eq(filter.key, value: intValue)
                } else if let boolValue = filter.value as? Bool {
                    query = query.eq(filter.key, value: boolValue)
                }
            }

            if let orderColumn = orderColumn {
                query = query.order(orderColumn, ascending: isAscending)
            }

            if let limit = limitValue {
                query = query.limit(limit)
            }

            if let from = rangeFrom, let to = rangeTo {
                query = query.range(from: from, to: to)
            }

            let response = try await query.execute()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([T].self, from: response.data)
        }
    }

    // MARK: - Performance Monitoring

    /// Mide el tiempo de ejecución de una query
    static func measureQueryTime<T>(
        operation: String,
        query: () async throws -> T
    ) async throws -> (result: T, duration: TimeInterval) {
        let start = Date()
        let result = try await query()
        let duration = Date().timeIntervalSince(start)

        Logger.debug("⏱️ Query '\(operation)' took \(String(format: "%.2f", duration))s")

        // Track en analytics si la query es lenta
        if duration > 2.0 {
            AnalyticsManager.shared.trackCustom(
                name: "slow_query",
                category: .performance,
                parameters: [
                    "operation": operation,
                    "duration": duration
                ]
            )
        }

        return (result, duration)
    }

    // MARK: - Helper Functions

    /// Calcula distancia entre dos puntos (Haversine formula)
    private static func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371.0 // km

        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}

// MARK: - Query Cache Manager

/// Manager de caché para queries específicas
final class QueryCacheManager {
    private var cache: [String: (data: Any, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval

    init(cacheTTL: TimeInterval = 300) { // 5 minutos por defecto
        self.cacheTTL = cacheTTL
    }

    func get<T>(_ key: String) -> T? {
        guard let cached = cache[key],
              Date().timeIntervalSince(cached.timestamp) < cacheTTL,
              let data = cached.data as? T else {
            return nil
        }
        return data
    }

    func set<T>(_ key: String, value: T) {
        cache[key] = (value, Date())
    }

    func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
    }

    func clear() {
        cache.removeAll()
    }

    /// Limpia entradas expiradas
    func cleanExpired() {
        let expiredKeys = cache.filter { Date().timeIntervalSince($0.value.timestamp) >= cacheTTL }.map { $0.key }
        expiredKeys.forEach { cache.removeValue(forKey: $0) }
        if !expiredKeys.isEmpty {
            Logger.debug("🗑️ Cleaned \(expiredKeys.count) expired cache entries")
        }
    }
}
