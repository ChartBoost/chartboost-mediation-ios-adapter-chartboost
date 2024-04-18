// Copyright 2022-2024 Chartboost, Inc.
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
        guard let size = Self.fixedBannerSize(for: request.bannerSize) else {
            throw adapter.error(.loadFailureInvalidBannerSize)
        }
        self.chartboostAd = CHBBanner(
            size: size,
            location: request.partnerPlacement,
            mediation: mediation,
            delegate: nil
        )
        self.size = PartnerBannerSize(size: size, type: .fixed)

        try super.init(adapter: adapter, request: request, delegate: delegate)
    }

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
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

    private static func fixedBannerSize(for requestedSize: BannerSize?) -> CGSize? {
        guard let requestedSize else {
            return IABStandardAdSize
        }
        let sizes = [IABLeaderboardAdSize, IABMediumAdSize, IABStandardAdSize]
        // Find the largest size that can fit in the requested size.
        for size in sizes {
            // If height is 0, the pub has requested an ad of any height, so only the width matters.
            if requestedSize.size.width >= size.width &&
                (size.height == 0 || requestedSize.size.height >= size.height) {
                return size
            }
        }
        // The requested size cannot fit any fixed size banners.
        return nil
    }
}

extension ChartboostAdapterBannerAd: CHBBannerDelegate {
    func didCacheAd(_ event: CHBCacheEvent, error partnerError: CacheError?) {
        // Report load finished
        if let partnerError = partnerError {
            // Partner load failure
            log(.loadFailed(partnerError))
            loadCompletion?(.failure(partnerError)) ?? log(.loadResultIgnored)
        } else if let viewController {
            // Success
            log(.loadSucceeded)

            // Chartboost Mediation expects banners to "show" immediately after being loaded and layed out, so we call show() on load.
            chartboostAd.show(from: viewController)

            loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        } else {
            // Banners require a view controller on load to be able to show
            let error = error(.showFailureViewControllerNotFound)
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
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

    func didFinishHandlingClick(_ event: CHBClickEvent, error: ClickError?) {
        log(.delegateCallIgnored)
    }
}
