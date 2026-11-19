cask "libby" do
  version "0.1.1"
  sha256 "892f33a0c1b6cb561094006a5545483a790bf00242f664c02b2a32e4a9162818"

  url "https://github.com/Markenos/Libby/releases/download/v#{version}/Libby.zip"
  name "Libby"
  desc "Mail, Messages, Calendar and Reminders in one place"
  homepage "https://github.com/Markenos/Libby"

  depends_on macos: ">= :tahoe"

  app "Libby.app"

  # Libby is ad-hoc signed (not notarized); clear the download quarantine so it opens.
  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/Libby.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.markenos.Libby.plist",
    "~/Library/Saved Application State/com.markenos.Libby.savedState",
  ]
end
