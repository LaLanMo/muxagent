class FirebaseRuntimeConfig {
  // Open-source builds ship placeholder Firebase config files. Keep Firebase
  // disabled unless the builder explicitly opts in with real project config.
  static const bool enabled = bool.fromEnvironment(
    'MUXAGENT_ENABLE_FIREBASE',
    defaultValue: false,
  );
}
