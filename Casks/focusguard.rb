cask "focusguard" do
  version "0.1.0"
  sha256 "3d1f3ca53e97a913175b59c3e439043fe3cbff09acc65c2e3e0155d32e3799d7"

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
