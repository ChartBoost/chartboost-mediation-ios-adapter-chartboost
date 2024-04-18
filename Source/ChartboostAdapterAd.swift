// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import ChartboostSDK
import Foundation

/// Base class for Chartboost Mediation Chartboost adapter ads.
class ChartboostAdapterAd: NSObject {
    
    /// The partner adapter that created this ad.
    let adapter: PartnerAdapter
    
    /// Extra ad information provided by the partner.
    var details: PartnerDetails = [:]

    /// The ad load request associated to the ad.
    /// It should be the one provided on ``PartnerAdapter/makeBannerAd(request:delegate:)``
    /// or ``PartnerAdapter/makeFullscreenAd(request:delegate:)``.
    let request: PartnerAdLoadRequest
    
    /// The partner ad delegate to send ad life-cycle events to.
    /// It should be the one provided on ``PartnerAdapter/makeBannerAd(request:delegate:)``
    /// or ``PartnerAdapter/makeFullscreenAd(request:delegate:)``.
    weak var delegate: PartnerAdDelegate?
    
    /// The completion for the ongoing load operation.
    private var loadCompletion: ((Result<PartnerDetails, Error>) -> Void)?
    
    /// The completion for the ongoing show operation.
    private var showCompletion: ((Result<PartnerDetails, Error>) -> Void)?
    
    /// The mediation object used to created Chartboost ads.
    var mediation: CHBMediation {
        .init(
            name: "Chartboost",
            libraryVersion: ChartboostMediation.sdkVersion,
            adapterVersion: adapter.adapterVersion
        )
    }

    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        self.request = request
        self.delegate = delegate
        self.adapter = adapter
    }
}

// Conformance to Chartboost ad delegate protocols
extension ChartboostAdapterAd where Self: PartnerAd {

    func didCacheAd(_ event: CHBCacheEvent, error partnerError: CacheError?) {
        // Report load finished
        if let partnerError = partnerError {
            log(.loadFailed(partnerError))
            loadCompletion?(.failure(partnerError)) ?? log(.loadResultIgnored)
        } else {
            log(.loadSucceeded)
            loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        }
        loadCompletion = nil
    }
    
    func willShowAd(_ event: CHBShowEvent) {
        log(.delegateCallIgnored)
    }
    
    func didShowAd(_ event: CHBShowEvent, error partnerError: ShowError?) {
        // Report show finished
        if let partnerError = partnerError {
            log(.showFailed(partnerError))
            showCompletion?(.failure(partnerError)) ?? log(.showResultIgnored)
        } else {
            log(.showSucceeded)
            showCompletion?(.success([:])) ?? log(.showResultIgnored)
        }
        showCompletion = nil
    }
    
    func didClickAd(_ event: CHBClickEvent, error: ClickError?) {
        // Report click
        log(.didClick(error: error))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func didRecordImpression(_ event: CHBImpressionEvent) {
        // Report impression tracked
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func didDismissAd(_ event: CHBDismissEvent) {
        // Report dismiss
        log(.didDismiss(error: event.error))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
    
    func didEarnReward(_ event: CHBRewardEvent) {
        // Report reward
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func didFinishHandlingClick(_ event: CHBClickEvent, error: ClickError?) {
        log(.delegateCallIgnored)
    }
}
