import 'package:flutter/widgets.dart';

/// Hand-picked Phosphor icons, referenced directly by codepoint against the
/// font files the `phosphor_flutter` package bundles (kept as a pubspec
/// dependency purely for its font assets — see pubspec.yaml).
///
/// `phosphor_flutter` 2.1.0's own Dart API (`PhosphorIconsRegular` etc.)
/// fails to compile on this Flutter SDK: its `PhosphorIconData extends
/// IconData`, and `IconData` became a `final class` (can no longer be
/// subclassed outside its own library) in a recent Flutter release, with
/// no newer package version yet published that fixes it. Working around it
/// this way needs no upstream fix and drops cleanly once one ships —
/// codepoints below were read from the installed package's own source
/// (`phosphor_icons_regular.dart` etc.), which are unaffected since only
/// the class *declaration* (not the icon data) is broken.
class PhosphorIcons {
  PhosphorIcons._();

  static const _regularFamily = 'PhosphorRegular';
  static const _fillFamily = 'PhosphorFill';
  static const _boldFamily = 'PhosphorBold';
  static const _package = 'phosphor_flutter';

  static const house = IconData(0xe2c2, fontFamily: _regularFamily, fontPackage: _package);
  static const houseFill = IconData(0xe2c2, fontFamily: _fillFamily, fontPackage: _package);

  static const scissors = IconData(0xeae0, fontFamily: _regularFamily, fontPackage: _package);
  static const scissorsFill = IconData(0xeae0, fontFamily: _fillFamily, fontPackage: _package);

  static const sparkle = IconData(0xe6a2, fontFamily: _regularFamily, fontPackage: _package);
  static const sparkleFill = IconData(0xe6a2, fontFamily: _fillFamily, fontPackage: _package);

  static const gearSix = IconData(0xe272, fontFamily: _regularFamily, fontPackage: _package);
  static const gearSixFill = IconData(0xe272, fontFamily: _fillFamily, fontPackage: _package);

  static const plusBold = IconData(0xe3d4, fontFamily: _boldFamily, fontPackage: _package);

  static const caretLeft = IconData(0xe138, fontFamily: _regularFamily, fontPackage: _package);
}
