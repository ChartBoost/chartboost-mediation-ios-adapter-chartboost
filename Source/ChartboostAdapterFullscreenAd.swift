// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import ChartboostSDK
import Foundation

/// Chartboost Mediation Chartboost adapter fullscreen ad.
final class ChartboostAdapterFullscreenAd: ChartboostAdapterAd, PartnerFullscreenAd, CHBInterstitialDelegate, CHBRewardedDelegate {

    /// The Chartboost SDK ad.
    private let chartboostAd: CHBAd

    override init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        switch request.format {
        case PartnerAdFormats.interstitial:
            chartboostAd = CHBInterstitial(
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: nil
            )
        case PartnerAdFormats.rewarded:
            chartboostAd = CHBRewarded(
                location: request.partnerPlacement,
                mediation: mediation,
                delegate: nil
            )
        default:
            throw adapter.error(.loadFailureUnsupportedAdFormat)
        }

        super.init(adapter: adapter, request: request, delegate: delegate)
    }

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
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
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.showStarted)

        // Save show completion to execute later on didShowAd
        showCompletion = completion

        // Show the ad
        chartboostAd.show(from: viewController)
    }
}
