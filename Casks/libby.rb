cask "libby" do
  version "0.1.2"
  sha256 "ffa9cfadb38b121d6d89e662598394c089d38f5feff160bf97458dfb8785a87f"

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
