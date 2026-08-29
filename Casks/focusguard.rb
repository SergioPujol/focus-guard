cask "focusguard" do
  version "0.1.0"
  sha256 "a583c173f8292b5af9d6bb5d7ea6fbea6ca851e9671bdd2f4eb01853abadd190"

  url "https://github.com/SergioPujol/focus-guard/releases/download/v#{version}/FocusGuard-macOS.zip"
  name "FocusGuard"
  desc "Menu bar utility for staying attached to an active promise"
  homepage "https://github.com/SergioPujol/focus-guard"

  depends_on macos: :ventura

  app "FocusGuard.app"

  uninstall quit: "app.focusguard.FocusGuard"

  zap trash: [
    "~/Library/Application Support/FocusGuard",
    "~/Library/Preferences/app.focusguard.FocusGuard.plist",
    "~/Library/Saved Application State/app.focusguard.FocusGuard.savedState",
  ]

  caveats <<~EOS
    FocusGuard preview builds are unsigned. If macOS blocks the first launch,
    Control-click FocusGuard in Applications, choose Open, and confirm it once.
  EOS
end
