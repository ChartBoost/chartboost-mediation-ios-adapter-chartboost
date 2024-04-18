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

        super.init(adapter: adapter, request: request, delegate: delegate)
    }

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)

        // Banners require a view controller on load to be able to show
        guard let viewController = viewController else {
            let error = error(.showFailureViewControllerNotFound)
            log(.loadFailed(error))
            completion(.failure(error))
            return
        }
        // Save load completion to execute later on didCacheAd.
        // Chartbosot Mediation expects banners to "show" immediately after being loaded and layed out, so we call show() on load.
        loadCompletion = { [weak self] result in
            if case .success = result {
                self?.chartboostAd.show(from: viewController)
            }
            completion(result)
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
