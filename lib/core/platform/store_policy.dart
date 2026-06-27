// lib/core/platform/store_policy.dart
import 'package:flutter/foundation.dart';

/// Whether to hide all in-app billing / purchase UI.
///
/// Returns true ONLY for the native iOS app, to comply with App Store Review
/// Guideline 3.1.1 / 3.1.3: an iOS app may not sell access to digital
/// content or services through an external payment system, nor show prices,
/// "buy" buttons, or links that steer users to outside purchase flows.
///
/// The web build (app.getlintel.org) keeps full billing — that is where real
/// subscriptions are taken via Flutterwave. The `!kIsWeb` guard is essential:
/// on Flutter web, `defaultTargetPlatform` reports `TargetPlatform.iOS` when
/// the site is opened in Safari on an iPhone, so without `!kIsWeb` we would
/// wrongly hide billing for web users on iOS devices.
///
/// A subscriber who paid on the web can still sign in on the iOS app and use
/// their plan — that is explicitly permitted under Guideline 3.1.3(b)
/// ("multiplatform services"). Only the purchasing UI is removed.
bool get kHideBillingForAppStore =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
