require "test_helper"

class Employee::PwaInstallationsControllerTest < ActionDispatch::IntegrationTest
  test "renders public install tutorial in employee auth layout" do
    get employee_pwa_installation_path

    assert_response :success
    assert_select "title", text: "Instal·lar l'aplicació | FitxaCAE"
    assert_select "html[data-pwa='employee'][data-employee-signed-in='false']"
    assert_select "body[data-controller~='employee-theme'][data-controller~='pwa-session'][data-controller~='submit-feedback']"
    assert_select ".employee-auth-card .brand-mark"
    assert_select ".employee-install-prompt", 0
    assert_select "h1", text: "Instal·la FitxaCAE"
    assert_select ".auth-tab-list", text: /Android/
    assert_select ".auth-tab-list", text: /iOS/
    assert_select "#pwa_install_android_tab[checked]"
    assert_select "#pwa_install_ios_tab[checked]", 0
    assert_select ".pwa-install-storyboard", 0
    assert_select "#pwa_install_android_panel .pwa-install-platform-copy", 0
    assert_select "#pwa_install_ios_panel .pwa-install-platform-copy", 0
    assert_select "#pwa_install_android_panel .pwa-install-step-image.pwa-install-step-screenshot-frame", 0
    assert_select "#pwa_install_android_panel .pwa-install-step-image img.pwa-install-step-screenshot[src*='pwa_install/android-']", 4
    assert_select "#pwa_install_android_panel .pwa-install-step-image img[src*='.svg']", 0
    assert_select "#pwa_install_ios_panel .pwa-install-step-image img.pwa-install-step-screenshot[src*='pwa_install/android-']", 0
    assert_select "#pwa_install_ios_panel .pwa-install-step-image img.pwa-install-step-screenshot[src*='pwa_install/ios-']", 6
    assert_select "#pwa_install_ios_panel .pwa-install-step-image img[src*='.svg']", 0
    assert_select ".pwa-install-step-image img[alt*='Captura del pas']", 10
    assert_select ".pwa-install-step", 10
    assert_select ".pwa-install-step > .pwa-install-step-body + .pwa-install-step-image", 10
    assert_select "#pwa_install_android_panel .pwa-install-step h3", 0
    assert_select "#pwa_install_ios_panel .pwa-install-step h3", 0
    assert_select "#pwa_install_android_panel .pwa-install-step-copy strong", text: "Obre FitxaCAE amb Google Chrome"
    assert_select "#pwa_install_android_panel .pwa-install-step-copy strong", text: "instal·la i crea una drecera"
    assert_select "#pwa_install_android_panel .pwa-install-step-copy em", text: "install and create shortcut"
    assert_select "#pwa_install_android_panel .pwa-install-step-copy strong", text: "pantalla d'inici"
    assert_select "#pwa_install_ios_panel .pwa-install-step-copy strong", text: "tres punts"
    assert_select "#pwa_install_ios_panel .pwa-install-step-copy strong", text: "Compartir"
    assert_select "#pwa_install_ios_panel .pwa-install-step-copy strong", text: "Ver más"
    assert_select "#pwa_install_ios_panel .pwa-install-step-copy strong", text: "Añadir a pantalla de inicio"
    assert_select "#pwa_install_ios_panel .pwa-install-step-copy strong", text: "Añadir"
    assert_select ".pwa-install-actions a[href='#{login_path}']", text: /Tornar a l'inici de sessió/
  end

  test "preselects android from user agent" do
    get employee_pwa_installation_path,
      headers: {
        "HTTP_USER_AGENT" => "Mozilla/5.0 (Linux; Android 16; Pixel 10) AppleWebKit/537.36 Chrome/141 Mobile Safari/537.36"
      }

    assert_response :success
    assert_select "#pwa_install_android_tab[checked]"
    assert_select "#pwa_install_ios_tab[checked]", 0
  end

  test "preselects ios from iphone user agent" do
    get employee_pwa_installation_path,
      headers: {
        "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 26_5 like Mac OS X) AppleWebKit/605.1.15 Version/26.0 Mobile/15E148 Safari/604.1"
      }

    assert_response :success
    assert_select "#pwa_install_ios_tab[checked]"
    assert_select "#pwa_install_android_tab[checked]", 0
  end

  test "preselects ios from ipados desktop-style user agent" do
    get employee_pwa_installation_path,
      headers: {
        "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_6) AppleWebKit/605.1.15 Version/26.0 Mobile/15E148 Safari/604.1"
      }

    assert_response :success
    assert_select "#pwa_install_ios_tab[checked]"
    assert_select "#pwa_install_android_tab[checked]", 0
  end
end
