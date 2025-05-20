// Copyright 2022-2025 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import ChartboostSDK
import Foundation

/// Chartboost Mediation Chartboost adapter banner ad.
final class ChartboostAdapterBannerAd: ChartboostAdapterAd, PartnerBannerAd {
    /// The partner banner ad view to display.
    var view: UIView? { chartboostAd }

    /// The loaded partner ad banner size.
    var size: PartnerBannerSize?

    /// The Chartboost SDK ad.
    private let chartboostAd: CHBBanner

    /// The view controller to show banners on.
    private weak var viewController: UIViewController?

    override init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        // Fail if we cannot fit a fixed size banner in the requested size.
        guard let requestedSize = request.bannerSize,
              let loadedSize = BannerSize.largestStandardFixedSizeThatFits(in: requestedSize)?.size else {
            throw adapter.error(.loadFailureInvalidBannerSize)
        }
        self.chartboostAd = CHBBanner(
            size: loadedSize,
            location: request.partnerPlacement,
            mediation: Self.mediation(for: adapter),
            delegate: nil
        )
        self.size = PartnerBannerSize(size: loadedSize, type: .fixed)

        try super.init(adapter: adapter, request: request, delegate: delegate)
    }

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)
        // Save view controller to show the banner later
        self.viewController = viewController

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
}

extension ChartboostAdapterBannerAd: CHBBannerDelegate {
    func didCacheAd(_ event: CHBCacheEvent, error partnerError: CacheError?) {
        // Report load finished
        if let partnerError {
            // Partner load failure
            log(.loadFailed(partnerError))
            loadCompletion?(partnerError) ?? log(.loadResultIgnored)
        } else if let viewController {
            // Success
            log(.loadSucceeded)

            // Chartboost Mediation expects banners to "show" immediately after being loaded and layed out, so we call show() on load.
            chartboostAd.show(from: viewController)

            loadCompletion?(nil) ?? log(.loadResultIgnored)
        } else {
            // Banners require a view controller on load to be able to show
            let error = error(.showFailureViewControllerNotFound)
            log(.loadFailed(error))
            loadCompletion?(error) ?? log(.loadResultIgnored)
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

    func didFinishHandlingClick(_ event: CHBClickEvent, error: ClickError?) {
        log(.delegateCallIgnored)
    }
}
