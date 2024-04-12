// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import ChartboostSDK
import Foundation

/// Chartboost Mediation Chartboost adapter.
final class ChartboostAdapter: PartnerAdapter {
    
    /// The version of the partner SDK.
    let partnerSDKVersion = Chartboost.getSDKVersion()
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.9.7.0.0"
    
    /// The partner's unique identifier.
    let partnerID = "chartboost"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "Chartboost"
    
    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) { }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.setUpStarted)
        // Get credentials, fail early if they are unavailable
        guard let appID = configuration.appID, let appSignature = configuration.appSignature else {
            let error = error(.initializationFailureInvalidCredentials, description: "Missing \(configuration.appID == nil ? String.appIDKey : String.appSignatureKey)")
            log(.setUpFailed(error))
            completion(error)
            return
        }
        // Start Chartboost
        Chartboost.start(withAppID: appID, appSignature: appSignature) { [self] error in
            if let error = error {
                log(.setUpFailed(error))
                completion(error)
            } else {
                log(.setUpSucceded)
                completion(nil)
            }
        }
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PartnerAdPreBidRequest, completion: @escaping (Result<[String : String], Error>) -> Void) {
        log(.fetchBidderInfoStarted(request))
        let bidderToken = Chartboost.bidderToken()
        log(.fetchBidderInfoSucceeded(request))
        completion(.success(bidderToken.map { ["buyeruid": $0] } ?? [:] ))
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        // This partner supports multiple loads for the same partner placement.
        try ChartboostAdapterAd(adapter: self, request: request, delegate: delegate)
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
        // See https://answers.chartboost.com/en-us/child_article/ios-privacy-methods
        if applies == true {
            let consent = CHBDataUseConsent.GDPR(status == .granted ? .behavioral : .nonBehavioral)
            Chartboost.addDataUseConsent(consent)
            log(.privacyUpdated(setting: consent.privacyStandard.rawValue, value: consent.consent.rawValue))
        } else {
            Chartboost.clearDataUseConsent(for: .GDPR)
            log(.privacyUpdated(setting: CHBPrivacyStandard.GDPR.rawValue, value: nil))
        }
    }
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
    func setCCPA(hasGivenConsent: Bool, privacyString: String) {
        // Set US privacy string
        // See https://answers.chartboost.com/en-us/child_article/ios-privacy-methods
        let consent = CHBDataUseConsent.Custom(privacyStandard: .CCPA, consent: privacyString)
        Chartboost.addDataUseConsent(consent)
        log(.privacyUpdated(setting: consent.privacyStandard.rawValue, value: consent.consent))
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
        // Set Chartboost COPPA consent
        // See https://answers.chartboost.com/en-us/child_article/ios-privacy-methods
        let consent = CHBDataUseConsent.COPPA(isChildDirected: isChildDirected)
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
private extension PartnerConfiguration {
    var appID: String? { credentials[.appIDKey] as? String }
    var appSignature: String? { credentials[.appSignatureKey] as? String }
}

private extension String {
    /// Chartboost app ID credentials key
    static let appIDKey = "app_id"
    /// Chartboost app signature credentials key
    static let appSignatureKey = "app_signature"
}
