class AppStrings {
  // App Info
  static const String appName = "RomaSub.AI";
  static const String appTagline = "Roman Urdu Caption Generator";

  // Auth
  static const String login = "Login";
  static const String signUp = "Sign Up";
  static const String loginTitle = "Welcome back";
  // Rendered as: "<subtitle><appName>" with the brand name in teal.
  static const String loginSubtitle = "Sign in to continue to ";
  static const String signupTitle = "Create your account";
  static const String signupSubtitle = "Sign up to continue to ";
  static const String email = "Email address";
  static const String emailHint = "you@example.com";
  static const String password = "Password";
  static const String passwordHint = "••••••••••";
  static const String firstName = "First name";
  static const String lastName = "Last name";
  static const String signIn = "Log In";
  static const String createAccount = "Create account";
  static const String rememberMe = "Remember me";

  // Auth — tab switcher (Log In / Sign Up)
  static const String tabLogIn = "Log In";
  static const String tabSignUp = "Sign Up";

  // The branded hero left panel is now a single finished image
  // (AppAssets.authHero); its lockup, tagline, feature pills, demo caption, and
  // quote are baked into the artwork rather than composed from strings here.

  // Auth — caption stage (legacy branded left panel, retained for reference)
  static const String authStageEyebrow = "CAPTION STUDIO";
  static const String authStageTagline = "Two scripts. One take.";
  static const String noAccount = "Don't have an account? ";
  static const String hasAccount = "Already have an account? ";
  static const String logIn = "Log in";
  static const String orDivider = "OR";
  static const String termsAgree = "I agree to the ";
  static const String termsConditions = "Terms & Conditions";
  static const String termsOfUse = "Terms of use";
  static const String privacyPolicy = "Privacy policy";

  // Social Login
  static const String continueGoogle = "Continue with Google";

  // Validation
  static const String emailRequired = "Email is required";
  static const String emailInvalid = "Please enter a valid email";
  static const String passwordRequired = "Password is required";
  static const String passwordShort = "Password must be at least 6 characters";
  static const String passwordMinLength =
      "Password must be at least 8 characters";
  static const String passwordNeedLetter =
      "Password must contain at least one letter";
  static const String passwordNeedDigit =
      "Password must contain at least one digit";
  static const String passwordNeedSpecial =
      "Password must contain at least one special character (!@#\$%^&*(),.?\":{}|<>_-+=[]\\/;~)";
  static const String confirmPasswordRequired = "Please confirm your password";
  static const String nameRequired = "Name is required";
  static const String nameInvalid = "Name must contain at least one letter";
  static const String acceptTerms = "Please agree to Terms & Conditions";

  // Navigation
  static const String dashboard = "Dashboard";
  static const String recentProjects = "Recent Projects";
  static const String exports = "Exports";
  static const String feedback = "Feedback";
  static const String settings = "Settings";
  static const String logout = "Log out";
  static const String yourAccount = "Your account";

  // Dashboard — upload drop zone
  static const String dashUploadTitle = "Drag & drop media to start editing";
  static const String dashUploadSubtitle =
      "Upload video or audio files to auto-generate Roman Urdu subtitles.";
  static const String dashGreetingSubtitle =
      "Upload a file to generate captions, or jump back into a recent project.";
  static const String dashUploadTapHint = "Tap to choose a file";
  static const String dashMaxSize = "MAX 2GB";

  // Dashboard — stat cards
  static const String dashTotalProjects = "TOTAL PROJECTS";
  static const String dashExports = "EXPORTS";

  // Dashboard — recent projects
  static const String dashRecentProjects = "RECENT PROJECTS";
  static const String dashViewAll = "View All";
  static const String dashNoProjects = "No projects yet";
  static const String dashNoProjectsHint =
      "Upload a file above to generate your first captions.";
  static const String dashProjectFlow = "Urdu → Roman Urdu";

  // Dashboard — system status
  static const String dashSystemStatus = "SYSTEM STATUS";
  static const String dashOnline = "Online";
  static const String dashUnreachable = "Unreachable";
  static const String dashChecking = "Checking…";
  static const String dashTranscription = "Transcription";
  static const String dashTransliteration = "Transliteration";
  static const String dashUnknownModel = "—";

  // Projects
  static const String allProjects = "All Projects";
  static const String searchProjects = "Search projects...";

  // Projects — table column headers
  static const String projectsColProject = "PROJECT";
  static const String projectsColFilename = "FILENAME";
  static const String projectsColDuration = "DURATION";
  static const String projectsColSegments = "SEGMENTS";
  static const String projectsColLastEdited = "LAST EDITED";

  // Projects — states
  static const String projectsEmptyTitle = "No projects yet";
  static const String projectsEmptySubtitle =
      "Upload a video or audio file to generate your first captions.";
  static const String projectsSearchEmpty = "No projects match your search";
  static const String projectsLoadError = "Failed to load projects";
  static const String refreshTooltip = "Refresh";

  // Exports
  static const String exportHistory = "Export History";

  // Feedback
  static const String feedbackTitle = "We Value Your Feedback";
  static const String feedbackSubtitle =
      "Help us improve RomaSub.AI by sharing your thoughts";
  static const String rateExperience = "Rate your experience";
  static const String yourFeedback = "Your feedback";
  static const String feedbackHint = "Tell us what worked and what didn't…";
  static const String submitFeedback = "Submit Feedback";
  static const String submittingFeedback = "Submitting…";
  static const String feedbackThanks = "Thank you for your feedback!";
  static const String feedbackRatePrompt = "Tap a star to rate";
  static const String feedbackSelectRating = "Please choose a rating first";
  // One word per star (index 0 = 1 star … index 4 = 5 stars).
  static const List<String> feedbackRatingLabels = <String>[
    "Poor",
    "Fair",
    "Good",
    "Great",
    "Excellent",
  ];
  static const String accountCreated = "Account created successfully!";

  // Forgot Password Flow
  static const String forgotPassword = "Forgot Password?";
  static const String forgotPasswordTitle = "Forgot Password";
  static const String enterEmailReset =
      "Enter your email to receive a reset code";
  static const String sendCode = "Send Code";
  static const String backToLogin = "Back to Login";
  static const String enterVerificationCode = "Enter Verification Code";
  static const String codeSentTo = "We sent a code to";
  static const String verifyCode = "Verify Code";
  static const String resendCode = "Resend Code";
  static const String createNewPassword = "Create New Password";
  static const String resetPasswordBtn = "Reset Password";
  static const String passwordResetSuccess = "Password reset successfully!";
  static const String otpInvalid = "Invalid OTP code";
  static const String otpExpired = "OTP code has expired";
  static const String otpResent = "New code sent to your email";
  static const String confirmPassword = "Confirm Password";
  static const String passwordsDoNotMatch = "Passwords do not match";

  // Settings Screen
  static const String profileSettings = "Profile Settings";
  static const String verified = "Verified";
  static const String currentPassword = "Current Password";
  static const String newPassword = "New Password";
  static const String updatePassword = "Update Password";
  static const String passwordUpdated = "Password updated successfully!";
  static const String profileUpdated = "Profile updated successfully!";
  static const String security = "Security";
  static const String profile = "Profile";
}
