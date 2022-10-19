//
//  ChartboostAdapter.swift
//  HeliumCanary
//
//  Created by Daniel Barros on 9/7/22.
//

import Foundation
import HeliumSdk
import ChartboostSDK

/// Helium Chartboost adapter.
final class ChartboostAdapter: PartnerAdapter {
    
    /// The version of the partner SDK.
    let partnerSDKVersion = Chartboost.getSDKVersion()
    
    /// The version of the adapter.
    /// The first digit is Helium SDK's major version. The last digit is the build version of the adapter. The intermediate digits correspond to the partner SDK version.
    let adapterVersion = "4.9.0.0.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "chartboost"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "Chartboost"
    
    /// The designated initializer for the adapter.
    /// Helium SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Helium SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) { }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        // Get credentials, fail early if they are unavailable
        guard let appID = configuration.appID, let appSignature = configuration.appSignature else {
            let error = error(.missingSetUpParameter(key: configuration.appID == nil ? .appIDKey : .appSignatureKey))
            log(.setUpFailed(error))
            completion(error)
            return
        }
        // Start Chartboost
        Chartboost.start(withAppID: appID, appSignature: appSignature) { [self] partnerError in
            if let partnerError = partnerError {
                let error = self.error(.setUpFailure, error: partnerError)
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
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]?) -> Void) {
        // Chartboost does not currently provide any bidding token
        completion(nil)
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Helium SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Helium SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        ChartboostAdapterAd(adapter: self, request: request, delegate: delegate)
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
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
    func setCCPAConsent(hasGivenConsent: Bool, privacyString: String?) {
        // Set Chartboost CCPA consent
        let consent = CHBDataUseConsent.CCPA(hasGivenConsent ? .optInSale : .optOutSale)
        Chartboost.addDataUseConsent(consent)
        log(.privacyUpdated(setting: consent.privacyStandard.rawValue, value: consent.consent.rawValue))
        
        // Set US privacy string if available
        if let privacyString = privacyString {
            let consent = CHBDataUseConsent.Custom(privacyStandard: .CCPA, consent: privacyString)
            Chartboost.addDataUseConsent(consent)
            log(.privacyUpdated(setting: consent.privacyStandard.rawValue, value: consent.consent))
        }
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isSubject: `true` if the user is subject, `false` otherwise.
    func setUserSubjectToCOPPA(_ isSubject: Bool) {
        // Set Chartboost COPPA consent
        let consent = CHBDataUseConsent.COPPA(isChildDirected: isSubject)
        Chartboost.addDataUseConsent(consent)
        log(.privacyUpdated(setting: consent.privacyStandard.rawValue, value: consent.isChildDirected))
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
