class AuthSession {
  static bool isDuressMode = false;
  static String activeDuressProfile = 'default';

  // Dynamic metadata key mapping based on active honey-pot vault profile
  static String get metadataKey {
    return isDuressMode ? 'vault_files_metadata_duress_$activeDuressProfile' : 'vault_files_metadata';
  }

  // Dynamic sandboxed files directory prefix based on active decoy profile
  static String get filesFolder {
    return isDuressMode ? 'sentry_vault_files_duress_$activeDuressProfile/' : 'sentry_vault_files/';
  }
}
