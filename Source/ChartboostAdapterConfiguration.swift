// Copyright 2022-2026 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import ChartboostSDK
import Foundation

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class ChartboostAdapterConfiguration: NSObject, PartnerAdapterConfiguration {
    /// The version of the partner SDK.
    @objc public static var partnerSDKVersion: String {
        Chartboost.getSDKVersion()
    }

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the 
    /// last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.
    /// <Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    @objc public static let adapterVersion = "5.9.14.0.0"

    /// The partner's unique identifier.
    @objc public static let partnerID = "chartboost"

    /// The human-friendly partner name.
    @objc public static let partnerDisplayName = "Chartboost"

    /// The consent key under which a CMP reports LGPD consent, for as long as Core defines no
    /// constant for it. Its value is `"true"` or `"false"`, indicating whether behavioral targeting
    /// is allowed, rather than one of the `ConsentValues` constants the other standards use.
    ///
    /// Any other value, and the absence of the key, mean the CMP is reporting no LGPD signal, which
    /// clears the standard from the Chartboost SDK.
    @objc public static let lgpdConsentKey = "CHB_LGPD_CONSENT"

    /// Flag that can optionally be set to enable the partner's verbose logging.
    /// Disabled by default.
    @objc public static var verboseLogging = false {
        didSet {
            Chartboost.setLoggingLevel(verboseLogging ? .verbose : .off)
            log("Verbose logging set to \(verboseLogging)")
        }
    }
}
