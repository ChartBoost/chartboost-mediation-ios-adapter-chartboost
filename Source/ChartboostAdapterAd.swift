// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import ChartboostSDK
import Foundation

/// Chartboost Mediation Chartboost adapter ad.
final class ChartboostAdapterAd: NSObject, PartnerAd {
    
    /// The partner adapter that created this ad.
    let adapter: PartnerAdapter
    
    /// The ad load request associated to the ad.
    /// It should be the one provided on `PartnerAdapter.makeAd(request:delegate:)`.
    let request: PartnerAdLoadRequest
    
    /// The partner ad delegate to send ad life-cycle events to.
    /// It should be the one provided on `PartnerAdapter.makeAd(request:delegate:)`.
    weak var delegate: PartnerAdDelegate?
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { chartboostAd as? UIView }
    
    /// The Chartboost SDK ad.
    private let chartboostAd: CHBAd
        
    /// The completion for the ongoing load operation.
    private var loadCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    /// The completion for the ongoing show operation.
    private var showCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        self.request = request
        self.delegate = delegate
        self.adapter = adapter
        self.chartboostAd = try Self.makeChartboostAd(adapter: adapter, request: request)
    }
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        // Save load completion to execute later on didCacheAd.
        // Banners are expected to show immediately after loading, so we call show() on load for banner ads only
        if request.format == .banner {
            // Banners require a view controller on load to be able to show
            guard let viewController = viewController else {
                let error = error(.showFailureViewControllerNotFound)
                log(.loadFailed(error))
                completion(.failure(error))
                return
            }
            // Banners show on load
            loadCompletion = { [weak self] result in
                if case .success = result {
                    self?.chartboostAd.show(from: viewController)
                }
                completion(result)
            }
        } else {
            // Interstitial and rewarded ads don't do anything extra
            loadCompletion = completion
        }
        
        // Set delegate
        chartboostAd.delegate = self
        
        // Load the ad
        if let adm = request.adm {
            // Programmatic load
            chartboostAd.cache(bidResponse: adm)
        } else {
            // Non-programmatic load
            chartboostAd.cache()
        }
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        
        // Save show completion to execute later on didShowAd
        showCompletion = completion
        
        // Show the ad
        chartboostAd.show(from: viewController)
    }
}

extension ChartboostAdapterAd: CHBInterstitialDelegate, CHBRewardedDelegate, CHBBannerDelegate {
    
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

private extension ChartboostAdapterAd {
    
    static func makeChartboostAd(adapter: PartnerAdapter, request: PartnerAdLoadRequest) throws -> CHBAd {
        let mediation = CHBMediation(
            name: "Chartboost",
            libraryVersion: Helium.sdkVersion,
            adapterVersion: adapter.adapterVersion
        )
        switch request.format {
        case .interstitial:
            return CHBInterstitial(
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: nil
            )
        case .rewarded:
            return CHBRewarded(
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: nil
            )
        case .banner:
            return CHBBanner(
                size: request.size ?? CHBBannerSizeStandard,    // Chartboost SDK supports the same sizes as Chartboost Mediation
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: nil
            )
        default:
            throw adapter.error(.loadFailureUnsupportedAdFormat)
        }
    }
}
