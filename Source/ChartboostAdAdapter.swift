//
//  ChartboostAdAdapter.swift
//  HeliumCanary
//
//  Created by Daniel Barros on 9/7/22.
//

import Foundation
import HeliumSdk
import ChartboostSDK

/// Helium Chartboost adapter ad wrapper.
final class ChartboostAdAdapter: NSObject, PartnerLogger, PartnerErrorFactory {
    
    /// The main adapter instance.
    let adapter: PartnerAdapter
    
    /// The load request that originated this ad.
    let request: AdLoadRequest
    
    /// The partner ad delegate to send ad life-cycle events to.
    weak var partnerAdDelegate: PartnerAdDelegate?
    
    /// The Chartboost SDK ad.
    private let chartboostAd: CHBAd
    
    /// The partner ad model passed in PartnerAdDelegate callbacks.
    private lazy var partnerAd = PartnerAd(ad: chartboostAd, details: [:], request: request)
    
    /// The completion for the ongoing load operation.
    private var loadCompletion: ((Result<PartnerAd, Error>) -> Void)?
    
    /// The completion for the ongoing show operation.
    private var showCompletion: ((Result<PartnerAd, Error>) -> Void)?
    
    init(adapter: PartnerAdapter, request: AdLoadRequest, partnerAdDelegate: PartnerAdDelegate) {
        self.request = request
        self.partnerAdDelegate = partnerAdDelegate
        self.adapter = adapter
        self.chartboostAd = Self.makeChartboostAd(request: request, adapter: adapter)
        super.init()
        self.chartboostAd.delegate = self
    }
    
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        // Save load completion to execute later on didCacheAd.
        // Banners are expected to show immediately after loading, so we call show() on load for banner ads only
        if request.format == .banner {
            // Banners require a view controller on load to be able to show
            guard let viewController = viewController else {
                let error = error(.noViewController)
                log(.loadFailed(request, error: error))
                completion(.failure(error))
                return
            }
            // Banners show on load
            loadCompletion = { [weak chartboostAd] result in
                chartboostAd?.show(from: viewController)
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
            let error = error(.noBidPayload(request))
            log(.loadFailed(request, error: error))
            completion(.failure(error))
        }
    }
    
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        // Save show completion to execute later on didShowAd
        showCompletion = completion
        // Show the ad
        chartboostAd.show(from: viewController)
    }
}

extension ChartboostAdAdapter: CHBInterstitialDelegate, CHBRewardedDelegate, CHBBannerDelegate {
    
    func didCacheAd(_ event: CHBCacheEvent, error partnerError: CHBCacheError?) {
        // Report load finished
        if let partnerError = partnerError {
            let error = error(.loadFailure(request), error: partnerError)
            log(.loadFailed(request, error: error))
            loadCompletion?(.failure(error))
        } else {
            log(.loadSucceeded(partnerAd))
            loadCompletion?(.success(partnerAd))
        }
        loadCompletion = nil
    }
    
    func willShowAd(_ event: CHBShowEvent) {
        log("Will show \(request.format) ad with placement \(request.partnerPlacement)")
    }
    
    func didShowAd(_ event: CHBShowEvent, error partnerError: CHBShowError?) {
        // Report show finished
        if let partnerError = partnerError {
            let error = error(.showFailure(partnerAd), error: partnerError)
            log(.showFailed(partnerAd, error: error))
            showCompletion?(.failure(error))
        } else {
            log(.showSucceeded(partnerAd))
            showCompletion?(.success(partnerAd))
        }
        showCompletion = nil
    }
    
    func didClickAd(_ event: CHBClickEvent, error: CHBClickError?) {
        // Report click
        log(.didClick(partnerAd, error: error))
        partnerAdDelegate?.didClick(partnerAd)
    }
    
    func didRecordImpression(_ event: CHBImpressionEvent) {
        // Report impression tracked
        log(.didTrackImpression(partnerAd))
        partnerAdDelegate?.didTrackImpression(partnerAd)
    }
    
    func didDismissAd(_ event: CHBDismissEvent) {
        // Report dismiss
        log(.didDismiss(partnerAd, error: nil))
        partnerAdDelegate?.didDismiss(partnerAd, error: nil)
    }
    
    func didEarnReward(_ event: CHBRewardEvent) {
        // Report reward
        let reward = Reward(amount: event.reward, label: nil)
        log(.didReward(partnerAd, reward: reward))
        partnerAdDelegate?.didReward(partnerAd, reward: reward)
    }
    
    func didFinishHandlingClick(_ event: CHBClickEvent, error: CHBClickError?) {
        log("Finished handling click for \(request.format) ad with placement \(request.partnerPlacement)")
    }
}

private extension ChartboostAdAdapter {
    
    static func makeChartboostAd(request: AdLoadRequest, adapter: PartnerAdapter) -> CHBAd {
        let mediation = CHBMediation(
            name: "Helium",
            libraryVersion: "", // TODO: Get from public property
            adapterVersion: adapter.adapterVersion
        )
        switch request.format {
        case .interstitial:
            return CHBInterstitial(
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: nil   // delegate is set later since `self` is not available at this point
            )
        case .rewarded:
            return CHBRewarded(
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: nil   // delegate is set later since `self` is not available at this point
            )
        case .banner:
            return CHBBanner(
                size: request.size ?? CHBBannerSizeStandard,    // Chartboost SDK supports the same sizes as Helium
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: nil   // delegate is set later since `self` is not available at this point
            )
        }
    }
}
