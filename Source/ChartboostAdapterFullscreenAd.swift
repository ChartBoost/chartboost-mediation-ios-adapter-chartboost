// Copyright 2022-2025 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import ChartboostSDK
import Foundation

/// Chartboost Mediation Chartboost adapter fullscreen ad.
final class ChartboostAdapterFullscreenAd: ChartboostAdapterAd, PartnerFullscreenAd {
    /// The Chartboost SDK ad.
    private let chartboostAd: CHBAd

    override init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        switch request.format {
        case PartnerAdFormats.interstitial:
            chartboostAd = CHBInterstitial(
                location: request.partnerPlacement,
                mediation: Self.mediation(for: adapter),
                delegate: nil
            )
        case PartnerAdFormats.rewarded:
            chartboostAd = CHBRewarded(
                location: request.partnerPlacement,
                mediation: Self.mediation(for: adapter),
                delegate: nil
            )
        default:
            throw adapter.error(.loadFailureUnsupportedAdFormat)
        }

        try super.init(adapter: adapter, request: request, delegate: delegate)
    }

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)

        // Save completion to be executed later
        loadCompletion = completion

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
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Error?) -> Void) {
        log(.showStarted)

        // Save show completion to execute later on didShowAd
        showCompletion = completion

        // Show the ad
        chartboostAd.show(from: viewController)
    }
}

extension ChartboostAdapterFullscreenAd: CHBInterstitialDelegate, CHBRewardedDelegate {
    func didCacheAd(_ event: CHBCacheEvent, error partnerError: CacheError?) {
        // Report load finished
        if let partnerError {
            log(.loadFailed(partnerError))
            loadCompletion?(partnerError) ?? log(.loadResultIgnored)
        } else {
            log(.loadSucceeded)
            loadCompletion?(nil) ?? log(.loadResultIgnored)
        }
        loadCompletion = nil
    }

    func willShowAd(_ event: CHBShowEvent) {
        log(.delegateCallIgnored)
    }

    func didShowAd(_ event: CHBShowEvent, error partnerError: ShowError?) {
        // Report show finished
        if let partnerError {
            log(.showFailed(partnerError))
            showCompletion?(partnerError) ?? log(.showResultIgnored)
        } else {
            log(.showSucceeded)
            showCompletion?(nil) ?? log(.showResultIgnored)
        }
        showCompletion = nil
    }

    func didClickAd(_ event: CHBClickEvent, error: ClickError?) {
        // Report click
        log(.didClick(error: error))
        delegate?.didClick(self) ?? log(.delegateUnavailable)
    }

    func didRecordImpression(_ event: CHBImpressionEvent) {
        // Report impression tracked
        log(.didTrackImpression)
        delegate?.didTrackImpression(self) ?? log(.delegateUnavailable)
    }

    func didDismissAd(_ event: CHBDismissEvent) {
        // Report dismiss
        log(.didDismiss(error: event.error))
        delegate?.didDismiss(self, error: nil) ?? log(.delegateUnavailable)
    }

    func didEarnReward(_ event: CHBRewardEvent) {
        // Report reward
        log(.didReward)
        delegate?.didReward(self) ?? log(.delegateUnavailable)
    }
}
