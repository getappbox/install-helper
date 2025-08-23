import Vapor
import Logging

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        #if swift(>=6.0)
        let app = try await Application.make(env)
        do {
            try await configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
        #else
        let app = Application(env)
        defer { app.shutdown() }
        do {
            try await configure(app)
            try app.run()
        } catch {
            app.logger.report(error: error)
            throw error
        }
        #endif
    }
}
