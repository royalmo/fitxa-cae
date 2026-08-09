require "test_helper"
require "csv"
require "tempfile"

class Admin::ImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
    log_in_manager
  end

  test "renders import page" do
    get new_admin_import_path

    assert_response :success
    assert_select "title", text: "Importació | FitxaCAE Admin"
    assert_select "h1", text: "Importació massiva"
    assert_select "a.btn.border-0[href='#{admin_employees_path}']", text: "Tornar"
    assert_select ".admin-bulk-action[data-controller='bulk-import'][data-bulk-import-simulate-url-value='#{simulate_admin_import_path}'][data-bulk-import-run-url-value='#{admin_import_path}']" do
      assert_select "form[action='#{admin_import_path}'][method='post']" do
        assert_select "input[type='hidden'][name='import[source]'][value='paste'][data-bulk-import-target='source']"
        assert_select "legend.form-label.small.text-body-secondary", text: "Etiquetes per a les noves persones (opcional)"
        assert_select ".admin-tag-multi-search[data-controller='tag-multi-search']"
        assert_select "input.admin-tag-multi-search-input[name='import_tag_query'][placeholder='Cerca una etiqueta']"
        assert_select "#admin-import-paste-tab.nav-link.active", text: "Enganxar dades"
        assert_select "#admin-import-file-tab.nav-link", text: "Pujar fitxer"
        assert_select "textarea[name='import[pasted_data]'][data-bulk-import-target='pastedData']"
        assert_select "textarea[placeholder*='Aina,Martinez Vidal'][placeholder*='Laia,Riera Soler']"
        assert_select "label[for='import_file']", count: 0
        assert_select "input[type='file'][name='import[file]'][aria-label='Fitxer'][data-bulk-import-target='fileInput']"
        assert_select "a[download='persones_import_template.csv'][data-bulk-import-target='templateLink']",
          text: "Descarregar plantilla"
        assert_select "label[for='import_pasted_data']", text: "Enganxa aquí les graelles d'excel que vols importar."
        assert_select "label[for='import_pasted_data']", text: /Dades/, count: 0
        assert_select "input[type='checkbox'][name='import[allow_second_surname]'][value='1'][data-bulk-import-target='allowSecondSurname']"
        assert_select "label[for='import_allow_second_surname']", text: "Permetre segon cognom"
        assert_select "[data-bulk-import-target='formatText']", text: "Format: Nom, Cognoms, DNI/NIE, correu, telèfon."
        assert_select "button[type='button'][disabled][data-bulk-import-target='simulateButton']", text: "Simular"
        assert_select ".alert.alert-danger.alert-dismissible[role='alert'][data-bulk-import-target='error'][hidden]" do
          assert_select "button.btn-close[type='button'][aria-label='Tancar avís'][data-action='bulk-import#dismissError']"
        end
        assert_select ".admin-bulk-simulation-results.card.shadow-sm.is-disabled[data-bulk-import-target='results']" do
          assert_select "[data-bulk-import-target='importableRatio']", text: "0/0"
          assert_select "[data-bulk-import-target='existingCount']", text: "0"
          assert_select "[data-bulk-import-target='tagCount']", count: 0
          assert_select ".fst-italic", text: "Les persones existents també rebran les etiquetes seleccionades."
          assert_select ".admin-bulk-affected-summary .text-primary[data-bulk-import-target='affectedCount']",
            text: "0"
          assert_select "button[type='button'][disabled][data-bulk-import-target='runButton']", text: "Importar persones"
        end
        assert_select "#adminImportConfirmModal.modal.fade" do
          assert_select ".modal-title", text: "Importar persones"
          assert_select "button[type='button'][data-bulk-import-target='confirmRunButton'][data-action='bulk-import#startRun']",
            text: "Sí, importar"
        end
        assert_select "#adminImportProgressModal.modal.fade" do
          assert_select ".modal-title", text: "Executant l'acció massiva"
          assert_select ".progress[data-bulk-import-target='runProgress']"
          assert_select ".progress-bar[data-bulk-import-target='runProgressBar']", text: "0%"
          assert_select "[data-bulk-import-target='runStatusMessage']"
        end
      end
    end
  end

  test "simulates pasted csv import with active tags" do
    tag = Tag.create!(name: "Acollida", color: "#2563eb", active: true)
    existing_employee = create_employee(national_id: valid_dni(45_000_001))
    new_national_id = valid_dni(45_000_002)
    content = import_csv([
      [ "Ada", "Soler", new_national_id, "ada@example.test", "600 111 222" ],
      [ "Aina", "Martinez", existing_employee.national_id, "aina@example.test", "600 333 444" ]
    ])

    post simulate_admin_import_path, params: { source: "paste", content: content, tag_ids: [ tag.id ] }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 2, payload.fetch("total_count")
    assert_equal 1, payload.fetch("importable_count")
    assert_equal 1, payload.fetch("existing_count")
    assert_equal 1, payload.fetch("existing_tag_update_count")
    assert_equal 2, payload.fetch("actionable_count")
    assert_not payload.key?("tag_count")
  end

  test "simulates pasted tab separated import" do
    national_id = valid_dni(45_000_003)
    content = [
      "Name\tSurname\tDNI/NIE\temail\tphone",
      "Laia\tRiera\t#{national_id}\tlaia@example.test\t600 555 666"
    ].join("\n")

    post simulate_admin_import_path, params: { source: "paste", content: content }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 1, payload.fetch("total_count")
    assert_equal 1, payload.fetch("importable_count")
    assert_equal 0, payload.fetch("existing_count")
  end

  test "simulates pasted import with second surname columns" do
    national_id = valid_dni(45_000_010)
    content = [
      "Nom\tPrimer cognom\tSegon cognom\tDNI/NIE\tcorreu\ttelèfon",
      "Laia\tRiera\tSoler\t#{national_id}\tlaia@example.test\t600 555 666"
    ].join("\n")

    post simulate_admin_import_path,
      params: { source: "paste", content: content, allow_second_surname: true },
      as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 1, payload.fetch("total_count")
    assert_equal 1, payload.fetch("importable_count")
  end

  test "rejects duplicated national ids in import simulation" do
    duplicated_national_id = valid_dni(45_000_004)
    content = import_csv([
      [ "Ada", "Soler", duplicated_national_id, "ada@example.test", "600 111 222" ],
      [ "Laia", "Riera", duplicated_national_id.downcase, "laia@example.test", "600 333 444" ]
    ])

    post simulate_admin_import_path, params: { source: "paste", content: content }, as: :json

    assert_response :unprocessable_entity
    assert_equal "El DNI/NIE #{duplicated_national_id} està duplicat 2 vegades.",
      JSON.parse(response.body).fetch("error")
  end

  test "rejects invalid national ids in import simulation" do
    content = import_csv([
      [ "Ada", "Soler", "bad", "ada@example.test", "600 111 222" ]
    ])

    post simulate_admin_import_path, params: { source: "paste", content: content }, as: :json

    assert_response :unprocessable_entity
    assert_equal "La fila 1 té un DNI/NIE no vàlid: bad.", JSON.parse(response.body).fetch("error")
  end

  test "enqueues pasted import and job creates employees and attaches tags" do
    tag = Tag.create!(name: "Formacio", color: "#16a34a", active: true)
    existing_employee = create_employee(national_id: valid_dni(45_000_005))
    first_national_id = valid_dni(45_000_006)
    second_national_id = valid_nie("X", 5_000_007)
    content = import_csv([
      [ "Ada", "Soler", first_national_id, "ada@example.test", "600 111 222" ],
      [ "Aina", "Martinez", existing_employee.national_id, "aina@example.test", "600 333 444" ],
      [ "Laia", "Riera", second_national_id, "laia@example.test", "600 555 666" ]
    ])

    assert_enqueued_with(job: ProcessEmployeeBulkActionRunJob) do
      post admin_import_path,
        params: {
          import: {
            source: "paste",
            pasted_data: content,
            tag_ids: [ tag.id ]
          }
        },
        as: :json
    end

    assert_response :accepted
    payload = JSON.parse(response.body)
    employee_bulk_action_run = EmployeeBulkActionRun.find(payload.fetch("id"))
    assert_equal "import", employee_bulk_action_run.kind
    assert_equal admin_employee_bulk_action_run_path(employee_bulk_action_run), payload.fetch("status_url")
    assert_nil Employee.find_by(national_id: first_national_id)
    audit_action = AuditAction.find_by!(kind: "employee_bulk_action.enqueued")
    assert_equal "import", audit_action.extra_info.fetch("bulk_action_kind")
    assert_equal [ tag.id ], audit_action.extra_info.fetch("tag_ids")
    assert_not_includes audit_action.extra_info.to_s, content
    assert_not_includes audit_action.extra_info.to_s, first_national_id

    assert_difference -> { Employee.count }, 2 do
      perform_enqueued_jobs(only: ProcessEmployeeBulkActionRunJob)
    end

    assert_enqueued_jobs 1, only: EmployeeWelcomeDeliveryJob
    assert_equal EmployeeWelcomeDeliveryJob, enqueued_jobs.last.fetch(:job)

    first_employee = Employee.find_by!(national_id: first_national_id)
    second_employee = Employee.find_by!(national_id: second_national_id)
    assert_equal "Ada", first_employee.first_name
    assert_equal "Soler", first_employee.last_name
    assert_equal "ada@example.test", first_employee.email
    assert_equal "600 111 222", first_employee.phone
    assert_predicate first_employee, :active?
    assert_equal [ tag ], first_employee.tags.to_a
    assert_equal [ tag ], second_employee.tags.to_a
    assert_equal [ tag ], existing_employee.reload.tags.to_a
    assert_equal "Importació completada. Persones noves: 2. Persones existents amb etiquetes noves: 1.",
      employee_bulk_action_run.reload.result_message

    perform_enqueued_jobs(only: EmployeeWelcomeDeliveryJob)
    assert_equal [ "ada@example.test", "laia@example.test" ], ActionMailer::Base.deliveries.map { |mail| mail.to.first }.sort
    assert_equal [ I18n.t("employee_welcome_mailer.welcome.subject", app_name: Rails.configuration.x.app_name) ],
      ActionMailer::Base.deliveries.map(&:subject).uniq
  end

  test "enqueues import from uploaded file" do
    national_id = valid_dni(45_000_008)
    uploaded_file = import_uploaded_file(import_csv([
      [ "Nora", "Vidal", national_id, "nora@example.test", "600 777 888" ]
    ]))

    assert_enqueued_with(job: ProcessEmployeeBulkActionRunJob) do
      post admin_import_path, params: {
        import: {
          source: "file",
          file: uploaded_file
        }
      }
    end

    assert_response :accepted
    employee_bulk_action_run = EmployeeBulkActionRun.find(JSON.parse(response.body).fetch("id"))

    assert_difference -> { Employee.count }, 1 do
      perform_enqueued_jobs(only: ProcessEmployeeBulkActionRunJob)
    end

    assert_equal "S'ha importat 1 persona.", employee_bulk_action_run.reload.result_message
    assert_equal "Nora", Employee.find_by!(national_id: national_id).first_name
  ensure
    uploaded_file&.tempfile&.close!
  end

  test "enqueues import joining two surname columns" do
    national_id = valid_dni(45_000_011)
    content = second_surname_import_csv([
      [ "Nora", "Vidal", "Puig", national_id, "nora@example.test", "600 777 888" ]
    ])

    assert_enqueued_with(job: ProcessEmployeeBulkActionRunJob) do
      post admin_import_path,
        params: {
          import: {
            source: "paste",
            allow_second_surname: "1",
            pasted_data: content
          }
        },
        as: :json
    end

    assert_response :accepted

    assert_difference -> { Employee.count }, 1 do
      perform_enqueued_jobs(only: ProcessEmployeeBulkActionRunJob)
    end

    assert_equal "Vidal Puig", Employee.find_by!(national_id: national_id).last_name
  end

  test "enqueues existing employee tag import when no new employees are created" do
    tag = Tag.create!(name: "Acollida existent", color: "#2563eb", active: true)
    existing_employee = create_employee(national_id: valid_dni(45_000_012))
    content = import_csv([
      [ "Aina", "Martinez", existing_employee.national_id, "aina@example.test", "600 333 444" ]
    ])

    assert_enqueued_with(job: ProcessEmployeeBulkActionRunJob) do
      post admin_import_path,
        params: {
          import: {
            source: "paste",
            pasted_data: content,
            tag_ids: [ tag.id ]
          }
        },
        as: :json
    end

    assert_response :accepted
    employee_bulk_action_run = EmployeeBulkActionRun.find(JSON.parse(response.body).fetch("id"))

    assert_no_difference -> { Employee.count } do
      perform_enqueued_jobs(only: ProcessEmployeeBulkActionRunJob)
    end

    assert_equal [ tag ], existing_employee.reload.tags.to_a
    assert_equal "S'han actualitzat les etiquetes d'1 persona existent.", employee_bulk_action_run.reload.result_message
  end

  test "rejects import when no people can be created" do
    existing_employee = create_employee(national_id: valid_dni(45_000_009))
    content = import_csv([
      [ "Aina", "Martinez", existing_employee.national_id, "aina@example.test", "600 333 444" ]
    ])

    assert_no_enqueued_jobs only: ProcessEmployeeBulkActionRunJob do
      assert_no_difference -> { Employee.count } do
        post admin_import_path,
          params: {
            import: {
              source: "paste",
              pasted_data: content
            }
          },
          as: :json
      end
    end

    assert_response :unprocessable_entity
    assert_equal "Aquesta importació no crearà cap persona ni afegirà cap etiqueta.",
      JSON.parse(response.body).fetch("error")
  end

  private

  def import_csv(rows)
    CSV.generate do |csv|
      csv << [ "Name", "Surname", "DNI/NIE", "email", "phone" ]
      rows.each { |row| csv << row }
    end
  end

  def second_surname_import_csv(rows)
    CSV.generate do |csv|
      csv << [ "Nom", "Primer cognom", "Segon cognom", "DNI/NIE", "correu", "telèfon" ]
      rows.each { |row| csv << row }
    end
  end

  def import_uploaded_file(content)
    file = Tempfile.new([ "employees-import", ".csv" ])
    file.write(content)
    file.rewind

    Rack::Test::UploadedFile.new(file.path, "text/csv")
  end
end
