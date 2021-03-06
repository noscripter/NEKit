import Foundation
import Yaml

struct AdapterFactoryParser {
    // swiftlint:disable:next cyclomatic_complexity
    static func parseAdapterFactoryManager(_ config: Yaml) throws -> AdapterFactoryManager {
        var factoryDict: [String: AdapterFactory] = [:]
        factoryDict["direct"] = DirectAdapterFactory()
        guard let adapterConfigs = config.array else {
            throw ConfigurationParserError.noAdapterDefined
        }

        for adapterConfig in adapterConfigs {
            guard let id = adapterConfig["id"].stringOrIntString else {
                throw ConfigurationParserError.adapterIDMissing
            }

            switch adapterConfig["type"].string?.lowercased() {
            case .some("speed"):
                factoryDict[id] = try parseSpeedAdapterFactory(adapterConfig, factoryDict: factoryDict)
            case .some("http"):
                factoryDict[id] = try parseServerAdapterFactory(adapterConfig, type: HTTPAdapterFactory.self)
            case .some("shttp"):
                factoryDict[id] = try parseServerAdapterFactory(adapterConfig, type: SecureHTTPAdapterFactory.self)
            case .some("ss"):
                factoryDict[id] = try parseShadowsocksAdapterFactory(adapterConfig)
            case .some("socks5"):
                factoryDict[id] = try parseSOCKS5AdapterFactory(adapterConfig)
            case .some("reject"):
                factoryDict[id] = try parseRejectAdapterFactory(adapterConfig)
            case nil:
                throw ConfigurationParserError.adapterTypeMissing
            default:
                throw ConfigurationParserError.adapterTypeUnknown
            }

        }
        return AdapterFactoryManager(factoryDict: factoryDict)
    }

    static func parseServerAdapterFactory(_ config: Yaml, type: HTTPAuthenticationAdapterFactory.Type) throws -> ServerAdapterFactory {
        guard let host = config["host"].string else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Host (host) is required.")
        }

        guard let port = config["port"].int else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Port (port) is required.")
        }

        var authentication: HTTPAuthentication? = nil
        if let auth = config["auth"].bool {
            if auth {
                guard let username = config["username"].stringOrIntString else {
                    throw ConfigurationParserError.adapterParsingError(errorInfo: "Username (username) is required.")
                }
                guard let password = config["password"].stringOrIntString else {
                    throw ConfigurationParserError.adapterParsingError(errorInfo: "Password (password) is required.")
                }
                authentication = HTTPAuthentication(username: username, password: password)
            }
        }
        return type.init(serverHost: host, serverPort: port, auth: authentication)
    }

    static func parseSOCKS5AdapterFactory(_ config: Yaml) throws -> SOCKS5AdapterFactory {
        guard let host = config["host"].string else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Host (host) is required.")
        }

        guard let port = config["port"].int else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Port (port) is required.")
        }

        return SOCKS5AdapterFactory(serverHost: host, serverPort: port)
    }

    static func parseShadowsocksAdapterFactory(_ config: Yaml) throws -> ShadowsocksAdapterFactory {
        guard let host = config["host"].string else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Host (host) is required.")
        }

        guard let port = config["port"].int else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Port (port) is required.")
        }

        guard let encryptMethod = config["method"].string else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Encryption method (method) is required.")
        }

        guard let password = config["password"].stringOrIntString else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Password (password) is required.")
        }

        let otaEnabled = config["ota"].bool ?? false
        let streamObfuscaterType = otaEnabled ? ShadowsocksAdapter.OTAStreamObfuscater.self as ShadowsocksStreamObfuscater.Type : ShadowsocksAdapter.OriginStreamObfuscater.self as ShadowsocksStreamObfuscater.Type

        return ShadowsocksAdapterFactory(serverHost: host, serverPort: port, encryptAlgorithm: encryptMethod, password: password, streamObfuscaterType: streamObfuscaterType)!
    }

    static func parseSpeedAdapterFactory(_ config: Yaml, factoryDict: [String:AdapterFactory]) throws -> SpeedAdapterFactory {
        var factories: [(AdapterFactory, Int)] = []
        guard let adapters = config["adapters"].array else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Speed Adatper should specify a set of adapters (adapters).")
        }
        for adapter in adapters {
            guard let id = adapter["id"].string else {
                throw ConfigurationParserError.adapterParsingError(errorInfo: "An adapter id (adapter_id) is required.")
            }
            guard let factory = factoryDict[id] else {
                throw ConfigurationParserError.adapterParsingError(errorInfo: "Unknown adapter id.")
            }
            guard let delay = adapter["delay"].int else {
                throw ConfigurationParserError.adapterParsingError(errorInfo: "Each adapter in Speed Adapter must specify a delay in millisecond.")
            }

            factories.append((factory, delay))
        }
        let adapter = SpeedAdapterFactory()
        adapter.adapterFactories = factories
        return adapter
    }

    static func parseRejectAdapterFactory(_ config: Yaml) throws -> RejectAdapterFactory {

        guard let delay = config["delay"].int else {
            throw ConfigurationParserError.adapterParsingError(errorInfo: "Reject adapter must specify a delay in millisecond.")
        }

        return RejectAdapterFactory(delay: delay)
    }
}
