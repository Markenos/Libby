cask "libby" do
  version "0.0.0"
  sha256 :no_check

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
