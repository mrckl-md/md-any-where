import Foundation
import Darwin

private struct TransportTestFailure: Error { let message: String }
private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw TransportTestFailure(message: message) }
}

@main
private enum AgentTransportTests {
    static func main() async {
        do {
            let origin = CommandLine.arguments[1]
            func request(_ path: String) -> URLRequest {
                var value = URLRequest(url: URL(string: origin + path)!, timeoutInterval: 10)
                value.httpMethod = "POST"
                value.httpBody = Data("public-test-document".utf8)
                value.setValue("fake-test-key", forHTTPHeaderField: "x-goog-api-key")
                value.setValue("fake-test-key", forHTTPHeaderField: "x-api-key")
                value.setValue("Bearer fake-test-key", forHTTPHeaderField: "Authorization")
                return value
            }
            let (success, response) = try await AgentHTTPTransport.response(to: request("/success"))
            try require((response as? HTTPURLResponse)?.statusCode == 200 &&
                        String(data: success, encoding: .utf8) == "public-test-document",
                        "A normal request must preserve its public test body")
            print("PASS: direct endpoint success")

            for target in ["same-host", "other-host"] {
                for status in [301, 302, 303, 307, 308] {
                    do {
                        _ = try await AgentHTTPTransport.response(to: request("/redirect/\(target)/\(status)"))
                        throw TransportTestFailure(message: "Followed \(target) HTTP \(status)")
                    } catch let error as NSError where error.domain == "Agent" && error.code == status {
                        // The original status must surface; no destination may be contacted.
                    }
                }
            }
            print("PASS: 301/302/303/307/308 rejected for same-host and cross-host destinations")

            let (errorBody, errorResponse) = try await AgentHTTPTransport.response(to: request("/error"))
            try require((errorResponse as? HTTPURLResponse)?.statusCode == 401 &&
                        String(data: errorBody, encoding: .utf8) == "{\"error\":{\"message\":\"test failure\"}}",
                        "Provider error responses must remain available to the caller")
            let (boundary, _) = try await AgentHTTPTransport.response(to: request("/limit"))
            try require(boundary.count == 4 * 1024 * 1024, "Exactly 4 MiB must be accepted")
            do {
                _ = try await AgentHTTPTransport.response(to: request("/oversize"))
                throw TransportTestFailure(message: "Oversize response accepted")
            } catch let error as NSError where error.domain == "Agent" && error.code == 413 {}
            print("PASS: error response and 4 MiB boundary remain intact")
        } catch {
            FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }
}
