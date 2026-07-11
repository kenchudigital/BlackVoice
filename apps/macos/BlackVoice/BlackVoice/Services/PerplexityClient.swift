//
//  PerplexityClient.swift
//  BlackVoice
//
//  做咩：Perplexity Agent API client（GET /v1/models + POST /v1/agent）。
//  目的：Settings list 同 Chat 用同一套 model id，唔再分 Sonar endpoint。
//  維護：API 變更 → 更新 endpoint / decode struct。

import Foundation

enum PerplexityClient {
    private static let agentEndpoint = URL(string: "https://api.perplexity.ai/v1/agent")!
    private static let modelsEndpoint = URL(string: "https://api.perplexity.ai/v1/models")!

    static func fetchModels(apiKey: String) async throws -> [PerplexityModelInfo] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw PerplexityClientError.missingAPIKey
        }

        var request = URLRequest(url: modelsEndpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")

        BlackVoiceLog.info(.app, "Perplexity fetch models")

        let data = try await performRequest(request)
        let decoded = try JSONDecoder().decode(ListModelsResponse.self, from: data)
        return decoded.data.map {
            PerplexityModelInfo(id: $0.id, ownedBy: $0.owned_by)
        }
    }

    /// 做咩：Chat 一律 POST /v1/agent；model id 同 GET /v1/models 一致。
    static func chat(
        apiKey: String,
        model: PerplexityModelInfo,
        messages: [ChatMessage]
    ) async throws -> AgentChatResult {
        try await agentChat(
            apiKey: apiKey,
            model: model.id,
            messages: messages
        )
    }

    private static func agentChat(
        apiKey: String,
        model: String,
        messages: [ChatMessage]
    ) async throws -> AgentChatResult {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw PerplexityClientError.missingAPIKey }
        guard !messages.isEmpty else { throw PerplexityClientError.emptyMessages }

        var request = URLRequest(url: agentEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AgentChatRequest(
                model: model,
                input: messages.map {
                    AgentChatRequest.InputMessage(
                        role: $0.role == .user ? "user" : "assistant",
                        content: $0.content
                    )
                },
                stream: false
            )
        )

        BlackVoiceLog.info(.app, "Perplexity agent chat — model: \(model), messages: \(messages.count)")

        let data = try await performRequest(request)
        let decoded = try JSONDecoder().decode(AgentChatResponse.self, from: data)

        if decoded.status == "failed" {
            let message = decoded.error?.message ?? "Agent request failed."
            throw PerplexityClientError.agentFailed(message)
        }

        guard let content = decoded.assistantText,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PerplexityClientError.emptyReply
        }

        let usage: TokenUsage?
        if let apiUsage = decoded.usage {
            usage = TokenUsage(
                inputTokens: apiUsage.input_tokens,
                outputTokens: apiUsage.output_tokens,
                totalTokens: apiUsage.total_tokens
            )
        } else {
            usage = nil
        }

        return AgentChatResult(text: content, usage: usage, modelID: model)
    }

    private static func performRequest(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            BlackVoiceLog.error(.app, "Perplexity network error: \(error.localizedDescription)")
            throw PerplexityClientError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw PerplexityClientError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            BlackVoiceLog.error(.app, "Perplexity HTTP \(http.statusCode): \(body)")
            throw PerplexityClientError.httpError(statusCode: http.statusCode, body: body)
        }
        return data
    }
}

enum PerplexityClientError: LocalizedError {
    case missingAPIKey
    case emptyMessages
    case invalidResponse
    case emptyReply
    case agentFailed(String)
    case network(URLError)
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add your Perplexity API token in Settings and press Save."
        case .emptyMessages:
            "No messages to send."
        case .invalidResponse:
            "Invalid response from Perplexity."
        case .emptyReply:
            "Perplexity returned an empty reply."
        case .agentFailed(let message):
            message
        case .network(let error):
            switch error.code {
            case .notConnectedToInternet:
                "No internet connection."
            case .cannotFindHost, .dnsLookupFailed:
                "Cannot reach api.perplexity.ai. Check your network connection."
            default:
                "Network error: \(error.localizedDescription)"
            }
        case .httpError(let statusCode, let body):
            if body.isEmpty {
                "Perplexity request failed (HTTP \(statusCode))."
            } else {
                "Perplexity request failed (HTTP \(statusCode)): \(body)"
            }
        }
    }
}

private struct ListModelsResponse: Decodable {
    struct ModelDTO: Decodable {
        let id: String
        let owned_by: String
    }

    let data: [ModelDTO]
}

private struct AgentChatRequest: Encodable {
    struct InputMessage: Encodable {
        let type = "message"
        let role: String
        let content: String
    }

    let model: String
    let input: [InputMessage]
    let stream: Bool
}

private struct AgentChatResponse: Decodable {
    struct ErrorInfo: Decodable {
        let message: String
    }

    struct OutputItem: Decodable {
        struct ContentPart: Decodable {
            let text: String?
        }

        let type: String
        let role: String?
        let content: [ContentPart]?
    }

    struct Usage: Decodable {
        let input_tokens: Int
        let output_tokens: Int
        let total_tokens: Int
    }

    let status: String
    let error: ErrorInfo?
    let output: [OutputItem]?
    let usage: Usage?

    var assistantText: String? {
        let parts = output?
            .filter { $0.type == "message" && $0.role == "assistant" }
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
        let joined = parts?.joined(separator: "\n")
        return joined?.isEmpty == false ? joined : nil
    }
}

struct AgentChatResult: Sendable {
    let text: String
    let usage: TokenUsage?
    let modelID: String
}
