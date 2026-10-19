

import 'package:flutter/widgets.dart';
import 'package:lumiere/localization/app_localizations.dart';

extension ContextX on BuildContext {
  AppLocalizations? get l10n => AppLocalizations.of(this);
}
