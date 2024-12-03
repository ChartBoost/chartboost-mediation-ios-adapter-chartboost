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
    var loadCompletion: ((Error?) -> Void)?

    /// The completion for the ongoing show operation.
    var showCompletion: ((Error?) -> Void)?

    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        self.request = request
        self.delegate = delegate
        self.adapter = adapter
    }
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        // Identical banner code is needed in two places because of how the switch statement is structured,
        // so wrap it in a local functon
        func loadBanner() {
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
        }

        switch request.format {
        case .banner:
            loadBanner()
        case .interstitial, .rewarded:
            // Interstitial and rewarded ads just need to save the completion so it can be called when load finishes.
            loadCompletion = completion
        default:
            // Not using the `.rewardedInterstitial` or `.adaptiveBanner` cases directly to maintain backward compatibility with Chartboost Mediation 4.0
            if request.format.rawValue == "rewarded_interstitial" {
                loadCompletion = completion
            } else if request.format.rawValue == "adaptive_banner" {
                loadBanner()
            } else {
                log(.loadFailed(error(.loadFailureUnsupportedAdFormat)))
            }
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

    /// The mediation object used to created Chartboost ads.
    static func mediation(for adapter: PartnerAdapter) -> CHBMediation {
        .init(
            name: "Chartboost",
            libraryVersion: ChartboostMediation.sdkVersion,
            adapterVersion: adapter.configuration.adapterVersion
        )
    }
}
