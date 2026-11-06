/// Page indexes of the home shell. Modules use these to jump to each other.
const kPageOverview = 0;
const kPageReviews = 1;
const kPagePosts = 2;
const kPageInsights = 3;
const kPageAiTools = 4;
const kPageBusinessProfile = 5;
const kPageAutomation = 6;
const kPageBilling = 7;
const kPageAccount = 8;

/// The page a suggested action is about, judged from the module and button the
/// server named. Null when nothing fits (the action then does not navigate).
int? pageForActionHint(String module, String cta) {
  final hint = '$module $cta'.toLowerCase();
  if (hint.contains('review')) return kPageReviews;
  if (hint.contains('post') || hint.contains('photo')) return kPagePosts;
  if (hint.contains('insight')) return kPageInsights;
  if (hint.contains('profile') ||
      hint.contains('hours') ||
      hint.contains('description') ||
      hint.contains('info')) {
    return kPageBusinessProfile;
  }
  if (hint.contains('automat')) return kPageAutomation;
  return null;
}
