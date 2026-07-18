cask "drovio" do
  version "1.1.4"
  sha256 :no_check # Set to actual SHA256 of the release DMG when deploying

  url "https://github.com/ombichave999/Drovio/releases/download/v#{version}/Drovio_#{version}.dmg"
  name "Drovio"
  desc "Native macOS menu bar downloader for YouTube, Instagram, and audio"
  homepage "https://github.com/ombichave999/Drovio"

  depends_on macos: ">= :sonoma"

  app "Drovio.app"

  zap trash: [
    "~/Library/Application Support/Drovio",
    "~/Library/Caches/com.drovio.Drovio",
    "~/Library/Preferences/com.drovio.Drovio.plist",
    "~/Library/Saved Application State/com.drovio.Drovio.savedState",
  ]
end
