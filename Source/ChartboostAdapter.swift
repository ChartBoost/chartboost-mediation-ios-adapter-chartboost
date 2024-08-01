// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import ChartboostSDK
import Foundation

/// Chartboost Mediation Chartboost adapter.
final class ChartboostAdapter: PartnerAdapter {
    /// The adapter configuration type that contains adapter and partner info.
    /// It may also be used to expose custom partner SDK options to the publisher.
    var configuration: PartnerAdapterConfiguration.Type { ChartboostAdapterConfiguration.self }

    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) { }

    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating
    /// the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.setUpStarted)
        // Get credentials, fail early if they are unavailable
        guard let appID = configuration.appID, let appSignature = configuration.appSignature else {
            let error = error(
                .initializationFailureInvalidCredentials,
                description: "Missing \(configuration.appID == nil ? String.appIDKey : String.appSignatureKey)"
            )
            log(.setUpFailed(error))
            completion(.failure(error))
            return
        }

        // Apply initial consents
        setConsents(configuration.consents, modifiedKeys: Set(configuration.consents.keys))
        setIsUserUnderage(configuration.isUserUnderage)

        // Start Chartboost
        Chartboost.start(withAppID: appID, appSignature: appSignature) { [self] error in
            if let error {
                log(.setUpFailed(error))
                completion(.failure(error))
            } else {
                log(.setUpSucceded)
                completion(.success([:]))
            }
        }
    }

    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PartnerAdPreBidRequest, completion: @escaping (Result<[String: String], Error>) -> Void) {
        log(.fetchBidderInfoStarted(request))
        let bidderToken = Chartboost.bidderToken()
        log(.fetchBidderInfoSucceeded(request))
        completion(.success(bidderToken.map { ["buyeruid": $0] } ?? [:] ))
    }

    /// Creates a new banner ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeBannerAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerBannerAd {
        // This partner supports multiple loads for the same partner placement.
        try ChartboostAdapterBannerAd(adapter: self, request: request, delegate: delegate)
    }

    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeFullscreenAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerFullscreenAd {
        // This partner supports multiple loads for the same partner placement.
        try ChartboostAdapterFullscreenAd(adapter: self, request: request, delegate: delegate)
    }

    /// Indicates that the user consent has changed.
    /// - parameter consents: The new consents value, including both modified and unmodified consents.
    /// - parameter modifiedKeys: A set containing all the keys that changed.
    func setConsents(_ consents: [ConsentKey: ConsentValue], modifiedKeys: Set<ConsentKey>) {
        // Set GDPR
        if modifiedKeys.contains(configuration.partnerID) || modifiedKeys.contains(ConsentKeys.gdprConsentGiven) {
            let consent = consents[configuration.partnerID] ?? consents[ConsentKeys.gdprConsentGiven]
            switch consent {
            case ConsentValues.granted, ConsentValues.denied:
                let consent = CHBDataUseConsent.GDPR(consent == ConsentValues.granted ? .behavioral : .nonBehavioral)
                Chartboost.addDataUseConsent(consent)
                log(.privacyUpdated(setting: consent.privacyStandard.rawValue, value: consent.consent.rawValue))
            default:
                Chartboost.clearDataUseConsent(for: .GDPR)
                log(.privacyUpdated(setting: CHBPrivacyStandard.GDPR.rawValue, value: nil))
            }
        }
        // Set US privacy string
        if modifiedKeys.contains(ConsentKeys.usp) {
            // See https://answers.chartboost.com/en-us/child_article/ios-privacy-methods
            if let privacyString = consents[ConsentKeys.usp] {
                let consent = CHBDataUseConsent.Custom(privacyStandard: .CCPA, consent: privacyString)
                Chartboost.addDataUseConsent(consent)
                log(.privacyUpdated(setting: consent.privacyStandard.rawValue, value: consent.consent))
            } else {
                Chartboost.clearDataUseConsent(for: .CCPA)
                log(.privacyUpdated(setting: CHBPrivacyStandard.CCPA.rawValue, value: nil))
            }
        }

        // CCPA consent (only if USP not available, since they are exclusive options for Chartboost)
        if modifiedKeys.contains(ConsentKeys.ccpaOptIn) && consents[ConsentKeys.usp] == nil {
            let consent = consents[ConsentKeys.ccpaOptIn]
            switch consent {
            case ConsentValues.granted, ConsentValues.denied:
                let consent = CHBDataUseConsent.CCPA(consent == ConsentValues.granted ? .optInSale : .optOutSale)
                Chartboost.addDataUseConsent(consent)
                log(.privacyUpdated(setting: consent.privacyStandard.rawValue, value: consent.consent.rawValue))
            default:
                Chartboost.clearDataUseConsent(for: .CCPA)
                log(.privacyUpdated(setting: CHBPrivacyStandard.CCPA.rawValue, value: nil))
            }
        }
    }

    /// Indicates that the user is underage signal has changed.
    /// - parameter isUserUnderage: `true` if the user is underage as determined by the publisher, `false` otherwise.
    func setIsUserUnderage(_ isUserUnderage: Bool) {
        // Set Chartboost COPPA consent
        // See https://answers.chartboost.com/en-us/child_article/ios-privacy-methods
        let consent = CHBDataUseConsent.COPPA(isChildDirected: isUserUnderage)
        Chartboost.addDataUseConsent(consent)
        log(.privacyUpdated(setting: consent.privacyStandard.rawValue, value: consent.isChildDirected))
    }

    /// Maps a partner setup error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a setup completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapSetUpError(_ error: Error) -> ChartboostMediationError.Code? {
        guard let error = error as? StartError,
              let code = error.startCode else {
            return nil
        }
        switch code {
        case .invalidCredentials:
            return .initializationFailureInvalidCredentials
        case .networkFailure:
            return .initializationFailureNetworkingError
        case .serverError:
            return .initializationFailureServerError
        @unknown default:
            return nil
        }
    }

    /// Maps a partner load error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a load completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapLoadError(_ error: Error) -> ChartboostMediationError.Code? {
        guard let error = error as? CacheError,
              let code = error.cacheCode else {
            return nil
        }
        switch code {
        case .internalError:
            return .loadFailureUnknown
        case .internetUnavailable:
            return .loadFailureNoConnectivity
        case .networkFailure:
            return .loadFailureNetworkingError
        case .noAdFound:
            return .loadFailureNoFill
        case .sessionNotStarted:
            return .loadFailurePartnerNotInitialized
        case .assetDownloadFailure:
            return .loadFailureNetworkingError
        case .publisherDisabled:
            return .loadFailureAborted
        case .serverError:
            return .loadFailureServerError
        @unknown default:
            return nil
        }
    }

    /// Maps a partner show error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a show completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapShowError(_ error: Error) -> ChartboostMediationError.Code? {
        guard let error = error as? ShowError,
              let code = error.showCode else {
            return nil
        }
        switch code {
        case .internalError:
            return .showFailureUnknown
        case .sessionNotStarted:
            return .showFailureNotInitialized
        case .internetUnavailable:
            return .showFailureNoConnectivity
        case .presentationFailure:
            return .showFailureUnknown
        case .noCachedAd:
            return .showFailureAdNotReady
        case .noViewController:
            return .showFailureViewControllerNotFound
        case .noAdInstance:
            return .showFailureAdNotFound
        case .assetsFailure:
            return .showFailureMediaBroken
        @unknown default:
            return nil
        }
    }
}

/// Convenience extension to access Chartboost credentials from the configuration.
extension PartnerConfiguration {
    fileprivate var appID: String? { credentials[.appIDKey] as? String }
    fileprivate var appSignature: String? { credentials[.appSignatureKey] as? String }
}

extension String {
    /// Chartboost app ID credentials key
    fileprivate static let appIDKey = "app_id"
    /// Chartboost app signature credentials key
    fileprivate static let appSignatureKey = "app_signature"
}
