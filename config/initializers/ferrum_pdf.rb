FerrumPdf.configure do |config|
  browser_path = [
    ENV["FERRUM_BROWSER_PATH"],
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/snap/bin/chromium",
    "/usr/bin/google-chrome"
  ].compact.find { |path| File.exist?(path) }
  config.browser_path = browser_path if browser_path

  if ENV["FERRUM_CHROME_NO_SANDBOX"] == "1"
    config.browser_options = { "no-sandbox" => true }
  end
end
