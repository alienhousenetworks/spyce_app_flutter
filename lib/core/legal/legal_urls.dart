import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';

Future<bool> openLegalUrl(String url) async {
  final uri = Uri.parse(url);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openPrivacyPolicy() => openLegalUrl(Env.privacyPolicyUrl);
Future<bool> openTermsOfService() => openLegalUrl(Env.termsOfServiceUrl);
Future<bool> openCommunityGuidelines() =>
    openLegalUrl(Env.communityGuidelinesUrl);
