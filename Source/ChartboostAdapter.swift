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
    
    /// The last value set on `setGDPRApplies(_:)`.
    private var gdprApplies = false
    /// The last value set on `setGDPRConsentStatus(_:)`.
    private var gdprStatus: GDPRConsentStatus = .unknown
    /// Ad adapters created on load, keyed by request identifier.
    private var ads: [String: ChartboostAdAdapter] = [:]
    
    let partnerSDKVersion = Chartboost.getSDKVersion()
    
    let adapterVersion = "4.9.0.0.0"
    
    let partnerIdentifier = "chartboost"
    
    let partnerDisplayName = "Chartboost"
    
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        // Get credentials, fail early if they are unavailable
        guard let appID = configuration.credentials["app_id"], let appSignature = configuration.credentials["app_signature"] else {
            let error = error(.missingSetUpParameter(key: configuration.credentials["app_id"] == nil ? "app_id" : "app_signature"))
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
    
    func load(request: AdLoadRequest, partnerAdDelegate: PartnerAdDelegate, viewController: UIViewController?, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        log(.loadStarted(request))
        // Running on main queue is required for banner creation since it's an UIView
        DispatchQueue.main.async { [self] in
            // Create ad adapter, save it and start loading
            let adAdapter = ChartboostAdAdapter(adapter: self, request: request, partnerAdDelegate: partnerAdDelegate)
            ads[request.identifier] = adAdapter
            adAdapter.load(with: viewController, completion: completion)
        }
    }
    
    func invalidate(_ partnerAd: PartnerAd, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        log(.invalidateStarted(partnerAd))
        if ads[partnerAd.request.identifier] == nil {
            // Fail if no ad to invalidate
            let error = error(.noAdToInvalidate(partnerAd))
            log(.invalidateFailed(partnerAd, error: error))
            completion(.failure(error))
        } else {
            // Succeed if we had an ad
            ads[partnerAd.request.identifier] = nil
            log(.invalidateSucceeded(partnerAd))
            completion(.success(partnerAd))
        }
    }
    
    func show(_ partnerAd: PartnerAd, viewController: UIViewController, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        log(.showStarted(partnerAd))
        // Fail if no ad available
        guard let ad = ads[partnerAd.request.identifier] else {
            let error = error(.noAdReadyToShow(partnerAd))
            log(.showFailed(partnerAd, error: error))
            completion(.failure(error))
            return
        }
        // Show the ad
        ad.show(with: viewController, completion: completion)
    }
    
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]) -> Void) {
        // Chartboost does not currently provide any bidding token
        log(.fetchBidderInfoStarted(request))
        log(.fetchBidderInfoSucceeded(request))
        completion([:])
    }
    
    func setGDPRApplies(_ applies: Bool) {
        // Save value and set GDPR on Chartboost using both gdprApplies and gdprStatus
        gdprApplies = applies
        updateGDPRConsent()
    }
    
    func setGDPRConsentStatus(_ status: GDPRConsentStatus) {
        // Save value and set GDPR on Chartboost using both gdprApplies and gdprStatus
        gdprStatus = status
        updateGDPRConsent()
    }
    
    private func updateGDPRConsent() {
        // Set Chartboost GDPR consent using both gdprApplies and gdprStatus
        if gdprApplies {
            Chartboost.addDataUseConsent(.GDPR(gdprStatus == .granted ? .behavioral : .nonBehavioral))
        } else {
            Chartboost.clearDataUseConsent(for: .GDPR)
        }
    }
    
    func setCCPAConsent(hasGivenConsent: Bool, privacyString: String?) {
        // Set Chartboost CCPA consent
        Chartboost.addDataUseConsent(.CCPA(hasGivenConsent ? .optInSale : .optOutSale))
        if let privacyString = privacyString {
            Chartboost.addDataUseConsent(.Custom(privacyStandard: .CCPA, consent: privacyString))
        }
    }
    
    func setUserSubjectToCOPPA(_ isSubject: Bool) {
        // Set Chartboost COPPA consent
        Chartboost.addDataUseConsent(.COPPA(isChildDirected: isSubject))
    }
}
