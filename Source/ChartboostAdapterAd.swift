//
//  ChartboostAdapterAd.swift
//  HeliumCanary
//
//  Created by Daniel Barros on 9/7/22.
//

import Foundation
import HeliumSdk
import ChartboostSDK

/// Helium Chartboost adapter ad.
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
    private var chartboostAd: CHBAd?
        
    /// The completion for the ongoing load operation.
    private var loadCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    /// The completion for the ongoing show operation.
    private var showCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) {
        self.request = request
        self.delegate = delegate
        self.adapter = adapter
    }
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        // Create Chartboost ad on main thread, since CHBBanner inherits from a UIKit class
        DispatchQueue.main.async { [self] in
            let chartboostAd = makeChartboostAd()
            self.chartboostAd = chartboostAd
            
            // Save load completion to execute later on didCacheAd.
            // Banners are expected to show immediately after loading, so we call show() on load for banner ads only
            if request.format == .banner {
                // Banners require a view controller on load to be able to show
                guard let viewController = viewController else {
                    let error = error(.noViewController)
                    log(.loadFailed(error))
                    completion(.failure(error))
                    return
                }
                // Banners show on load
                loadCompletion = { [weak chartboostAd] result in
                    if case .success = result {
                        chartboostAd?.show(from: viewController)
                    }
                    completion(result)
                }
            } else {
                // Interstitial and rewarded ads don't do anything extra
                loadCompletion = completion
            }
            
            // Load the ad
            if request.adm == nil {
                // Non-programmatic load
                chartboostAd.cache()
            } else if let bidResponse = request.partnerSettings["bid_response"] {
                // Programmatic load
                chartboostAd.cache(bidResponse: bidResponse)
            } else {
                // Programmatic load missing the bid_response setting
                let error = error(.noBidPayload)
                log(.loadFailed(error))
                completion(.failure(error))
            }
        }
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        
        // Fail early if no ad
        guard let chartboostAd = chartboostAd else {
            let error = error(.noAdReadyToShow)
            log(.showFailed(error))
            return completion(.failure(error))
        }
        
        // Save show completion to execute later on didShowAd
        showCompletion = completion
        
        // Show the ad
        chartboostAd.show(from: viewController)
    }
}

extension ChartboostAdapterAd: CHBInterstitialDelegate, CHBRewardedDelegate, CHBBannerDelegate {
    
    func didCacheAd(_ event: CHBCacheEvent, error partnerError: CHBCacheError?) {
        // Report load finished
        if let partnerError = partnerError {
            let error = error(.loadFailure, error: partnerError)
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        } else {
            log(.loadSucceeded)
            loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        }
        loadCompletion = nil
    }
    
    func willShowAd(_ event: CHBShowEvent) {
        log("Will show \(request.format) ad with placement \(request.partnerPlacement)")
    }
    
    func didShowAd(_ event: CHBShowEvent, error partnerError: CHBShowError?) {
        // Report show finished
        if let partnerError = partnerError {
            let error = error(.showFailure, error: partnerError)
            log(.showFailed(error))
            showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        } else {
            log(.showSucceeded)
            showCompletion?(.success([:])) ?? log(.showResultIgnored)
        }
        showCompletion = nil
    }
    
    func didClickAd(_ event: CHBClickEvent, error: CHBClickError?) {
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
        let reward = Reward(amount: event.reward, label: nil)
        log(.didReward(reward))
        delegate?.didReward(self, details: [:], reward: reward) ?? log(.delegateUnavailable)
    }
    
    func didFinishHandlingClick(_ event: CHBClickEvent, error: CHBClickError?) {
        log("Finished handling click for \(request.format) ad with placement \(request.partnerPlacement)")
    }
}

private extension ChartboostAdapterAd {
    
    func makeChartboostAd() -> CHBAd {
        let mediation = CHBMediation(
            name: "Helium",
            libraryVersion: Helium.sdkVersion,
            adapterVersion: adapter.adapterVersion
        )
        switch request.format {
        case .interstitial:
            return CHBInterstitial(
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: self
            )
        case .rewarded:
            return CHBRewarded(
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: self
            )
        case .banner:
            return CHBBanner(
                size: request.size ?? CHBBannerSizeStandard,    // Chartboost SDK supports the same sizes as Helium
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: self
            )
        }
    }
}