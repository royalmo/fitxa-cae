if Rails.env.production? && ENV["ALLOW_PRODUCTION_SEEDS"] != "1"
  abort "Refusing to load destructive demo seeds in production. Set ALLOW_PRODUCTION_SEEDS=1 to override intentionally."
end

rng = Random.new(20_260_630)

DNI_LETTERS = "TRWAGMYFPDXBNJZSQVHLCKE"

FIRST_NAMES = %w[
  Ada Aina Alexia Arnau Biel Carla David Diana Eloi Emma Enric Eva Ferran
  Gemma Gerard Helena Ines Jan Joana Jordi Julia Laia Leo Lluc Marc Marta
  Martina Mireia Nadia Nil Nora Oriol Paula Pol Quim Rita Roger Sara Sergi
  Silvia Teo Txell Victor Xavi Abril Bruno Clara Daniel Elisa Fran Gina Hugo
  Irene Joel Lara Mario Noa Oscar Petra Raul Sonia Tomas Vera
].freeze

LAST_NAMES = [
  "Garcia Roca", "Martinez Vidal", "Lopez Soler", "Sanchez Puig",
  "Perez Costa", "Rodriguez Serra", "Fernandez Vila", "Gonzalez Pujol",
  "Gomez Ferrer", "Ruiz Casas", "Diaz Mas", "Hernandez Coll",
  "Moreno Bosch", "Alvarez Comas", "Romero Riera", "Navarro Font",
  "Torres Prat", "Dominguez Esteve", "Vazquez Rovira", "Ramos Duran",
  "Gil Planas", "Ramirez Sola", "Serrano Cabot", "Molina Camps",
  "Blanco Grau", "Morales Miro", "Ortega Ros", "Delgado Serra",
  "Castro Pons", "Ortiz Nadal", "Rubio Fabregas", "Marin Codina",
  "Sanz Boix", "Iglesias Rius", "Medina Vives", "Cortes Pardo",
  "Garrido Mateu", "Castillo Vila", "Santos Puig", "Guerrero Sole",
  "Cano Roca", "Prieto Vidal", "Mendez Pujol", "Cruz Costa",
  "Calvo Serra", "Gallego Riera", "Vega Prat", "Reyes Font",
  "Herrera Comas", "Flores Bosch", "Aguilar Casas", "Soler Roca",
  "Pascual Vidal", "Riera Puig", "Pons Costa", "Serra Vila",
  "Vila Coll", "Ferrer Mas", "Font Prat", "Bosch Planas",
  "Costa Grau", "Puig Miro", "Prat Rius", "Roca Camps",
  "Vidal Ros", "Miro Pons", "Comas Boix", "Duran Serra",
  "Nadal Font", "Codina Riera"
].freeze

CORRECTION_REASONS = [
  "Oblit de fitxatge d'entrada",
  "Oblit de fitxatge de sortida",
  "Canvi de torn comunicat tard",
  "Terminal sense connexio",
  "Error en seleccionar entrada o sortida",
  "Visita a client registrada manualment",
  "Sortida medica justificada"
].freeze

TERMINALS = [ "terminal:recepcio", "terminal:magatzem", "terminal:app", "terminal:oficina" ].freeze

def dni(number)
  digits = number % 100_000_000
  "#{digits.to_s.rjust(8, "0")}#{DNI_LETTERS[digits % DNI_LETTERS.length]}"
end

def nie(prefix, number)
  body = (number % 10_000_000).to_s.rjust(7, "0")
  translated_prefix = { "X" => "0", "Y" => "1", "Z" => "2" }.fetch(prefix)
  numeric_value = "#{translated_prefix}#{body}".to_i

  "#{prefix}#{body}#{DNI_LETTERS[numeric_value % DNI_LETTERS.length]}"
end

def email_address(first_name, last_name, index)
  normalized_last_name = last_name.split.first.downcase
  "#{first_name.downcase}.#{normalized_last_name}#{index + 1}@fitxa-cae.test"
end

def phone_number(index)
  "+34 6#{(20 + (index % 70)).to_s.rjust(2, "0")} " \
    "#{(100 + ((index * 37) % 900)).to_s.rjust(3, "0")} " \
    "#{(100 + ((index * 53) % 900)).to_s.rjust(3, "0")}"
end

def work_time(day, hour, minute)
  Time.zone.local(day.year, day.month, day.day, hour, minute)
end

def weekday?(date)
  date.cwday <= 5
end

def spread_demo_workdays(days)
  return days.first(3) if days.length <= 5

  [ days[1], days[days.length / 2], days[-2] ].compact.uniq
end

def demo_multi_swipe_patterns
  [
    [
      [ "entry", 8, 5 ],
      [ "exit", 12, 10 ],
      [ "entry", 13, 0 ]
    ],
    [
      [ "entry", 7, 58 ],
      [ "exit", 12, 30 ],
      [ "entry", 14, 0 ],
      [ "exit", 17, 12 ]
    ],
    [
      [ "entry", 7, 54 ],
      [ "exit", 10, 15 ],
      [ "entry", 10, 34 ],
      [ "exit", 13, 8 ],
      [ "entry", 14, 2 ],
      [ "exit", 17, 41 ]
    ]
  ]
end

def seed_correction_audit_details(correction, extra_info = {})
  details = correction.details || {}
  requested_swipes = Array(details["requested_swipes"]).map do |requested_swipe|
    {
      "kind" => requested_swipe["kind"].to_s,
      "hour" => requested_swipe["hour"].to_s
    }
  end

  {
    correction_id: correction.id,
    day: correction.day&.iso8601,
    status: correction.status,
    invalidated_swipe_ids: Array(details["invalidated_swipe_ids"]).map(&:to_s),
    requested_swipes: requested_swipes,
    requested_swipe_count: requested_swipes.size,
    invalidated_swipe_count: Array(details["invalidated_swipe_ids"]).compact_blank.size
  }.merge(extra_info)
end

ActiveRecord::Base.transaction do
  ReportExport.find_each { |report_export| report_export.artifact.purge if report_export.artifact.attached? }
  connection = ActiveRecord::Base.connection

  %w[
    audit_actions
    swipe_corrections
    swipes
    report_exports
    managers
    employment_periods
    employees_tags
    employees
    tags
  ].each do |table|
    connection.execute("DELETE FROM #{table}")
  end

  tags = {
    office: Tag.create!(name: "office", active: true, color: "#2563eb"),
    wharehouse: Tag.create!(name: "wharehouse", active: true, color: "#16a34a"),
    off_shore: Tag.create!(name: "off-shore", active: false, color: "#6b7280")
  }

  employees = 70.times.map do |index|
    first_name = FIRST_NAMES[index % FIRST_NAMES.length]
    last_name = LAST_NAMES[index]
    active = index < 60
    has_phone = index % 4 != 0
    has_email = index % 3 != 0
    has_password = index % 5 != 0
    national_id = if index % 9 == 0
      nie(%w[X Y Z][(index / 9) % 3], 1_430_000 + (index * 137))
    else
      dni(31_000_000 + (index * 7_919))
    end

    employee = Employee.create!(
      first_name: first_name,
      last_name: last_name,
      national_id: national_id,
      phone: has_phone ? phone_number(index) : nil,
      email: has_email ? email_address(first_name, last_name, index) : nil,
      active: active,
      password: has_password ? "1234" : nil,
      settings: {}
    )

    employee.tags = [
      (tags[:office] if index.even?),
      (tags[:wharehouse] if (index % 3).zero? || index % 7 == 2),
      (tags[:off_shore] if (index % 13).zero? || (!active && index.even?))
    ].compact.uniq

    employee
  end

  managers = [
    [ "Laia", "Riera", "laia.riera@fitxa-cae.test", employees[0] ],
    [ "Marc", "Soler", "marc.soler@fitxa-cae.test", employees[1] ],
    [ "Nuria", "Costa", "nuria.costa@fitxa-cae.test", nil ],
    [ "Pau", "Vidal", "pau.vidal@fitxa-cae.test", nil ]
  ].map do |first_name, last_name, email, employee|
    Manager.create!(
      first_name: first_name,
      last_name: last_name,
      email: email,
      active: true,
      employee: employee,
      password: "12345678",
      settings: {}
    )
  end

  today = Time.zone.today
  workdays = ((today - 75)...today).select { |day| weekday?(day) }.last(45)
  swipes_by_employee_and_day = Hash.new { |hash, key| hash[key] = [] }

  employees.each_with_index do |employee, employee_index|
    employee_workdays = employee.active? ? workdays : workdays.first(24)

    employee_workdays.each_with_index do |day, day_index|
      next if (employee_index + day_index) % 17 == 0

      entry_minute = 45 + rng.rand(0..35)
      exit_minute = rng.rand(0..45)
      entry_at = work_time(day, 7 + (entry_minute / 60), entry_minute % 60)
      exit_at = work_time(day, 16 + rng.rand(0..1), exit_minute)

      [ [ "entry", entry_at ], [ "exit", exit_at ] ].each do |kind, swipe_at|
        next if rng.rand < 0.025

        swipe = Swipe.create!(
          employee: employee,
          swipe_at: swipe_at,
          kind: kind,
          removed: false,
          metadata: TERMINALS.sample(random: rng),
          forged: rng.rand < 0.01
        )

        swipes_by_employee_and_day[[ employee.id, day ]] << swipe
      end
    end
  end

  aina = employees.find { |employee| employee.first_name == "Aina" && employee.last_name == "Martinez Vidal" }
  if aina
    workdays.group_by { |day| [ day.year, day.month ] }.each_value do |month_workdays|
      spread_demo_workdays(month_workdays).each_with_index do |day, pattern_index|
        Swipe.where(employee: aina, swipe_at: day.all_day).delete_all

        day_swipes = demo_multi_swipe_patterns[pattern_index % demo_multi_swipe_patterns.length].map do |kind, hour, minute|
          Swipe.create!(
            employee: aina,
            swipe_at: work_time(day, hour, minute),
            kind: kind,
            removed: false,
            metadata: TERMINALS.sample(random: rng),
            forged: false
          )
        end

        swipes_by_employee_and_day[[ aina.id, day ]] = day_swipes
      end
    end
  end

  employees.each do |employee|
    first_swipe_at = employee.swipes.kept.minimum(:swipe_at)
    last_swipe_at = employee.swipes.kept.maximum(:swipe_at)
    next unless first_swipe_at

    employee.employment_periods.delete_all
    employee.employment_periods.create!(
      started_at: first_swipe_at,
      ended_at: employee.active? ? nil : last_swipe_at + 1.second
    )
    employee.update_columns(
      created_at: [ employee.created_at, first_swipe_at ].min,
      updated_at: Time.current
    )
  end

  employees.each_with_index do |employee, employee_index|
    correction_count = (employee_index * 5) % 21
    correction_days = workdays.sample(correction_count, random: rng)

    correction_days.each_with_index do |day, correction_index|
      status = case (employee_index + correction_index) % 5
      when 0
        "pending"
      when 1, 2
        "approved"
      else
        "rejected"
      end
      day_swipes = swipes_by_employee_and_day[[ employee.id, day ]]
      invalidated_swipes = day_swipes.sample([ day_swipes.length, rng.rand(0..2) ].min, random: rng)
      invalidated_swipes = [ day_swipes.sample(random: rng) ] if status == "pending" && invalidated_swipes.empty? && day_swipes.any?
      requested_swipes = [
        {
          "kind" => "entry",
          "hour" => work_time(day, 8, rng.rand(0..20)).strftime("%H:%M:%S")
        },
        {
          "kind" => "exit",
          "hour" => work_time(day, 17, rng.rand(0..30)).strftime("%H:%M:%S")
        }
      ]
      requested_swipes.shift if correction_index % 9 == 0
      requested_swipes.pop if correction_index % 11 == 0 && requested_swipes.length > 1

      requester = if (employee_index + correction_index) % 6 == 0
        managers.sample(random: rng)
      else
        employee
      end
      validator = status == "pending" ? nil : managers.sample(random: rng)

      SwipeCorrection.create!(
        employee: employee,
        requester: requester,
        validator: validator,
        status: status,
        day: day,
        details: {
          "invalidated_swipe_ids" => invalidated_swipes.map(&:id),
          "requested_swipes" => requested_swipes
        },
        requester_comments: CORRECTION_REASONS.sample(random: rng),
        validator_comments: validator ? "#{status}: revisat pel responsable de torn" : nil
      )
    end
  end

  audit_author = managers.first
  secondary_manager = managers.second
  employee = employees.first
  inactive_employee = employees.find { |seed_employee| !seed_employee.active? } || employees.last
  pending_correction = SwipeCorrection.pending.first
  approved_correction = SwipeCorrection.approved.first
  rejected_correction = SwipeCorrection.rejected.first
  audit_started_at = Time.current - 14.days

  audit_rows = [
    {
      author: audit_author,
      recipient: employee,
      kind: "employee.created",
      extra_info: {
        changed_fields: %w[first_name last_name national_id email phone active],
        tag_ids: employee.tag_ids,
        tags: employee.tags.order(:name).pluck(:name),
        welcome_email_enqueued: employee.email.present?
      }
    },
    {
      author: audit_author,
      recipient: employee,
      kind: "employee.updated",
      extra_info: {
        changed_fields: %w[email phone tags],
        added_tag_ids: [ tags[:office].id ],
        added_tags: [ tags[:office].name ]
      }
    },
    {
      author: audit_author,
      recipient: inactive_employee,
      kind: "employee.deactivated",
      extra_info: {
        changed_fields: [ "active" ],
        changes: { active: { from: true, to: false } }
      }
    },
    {
      author: audit_author,
      recipient: inactive_employee,
      kind: "employee.activated",
      extra_info: {
        changed_fields: [ "active" ],
        changes: { active: { from: false, to: true } }
      }
    },
    {
      author: audit_author,
      recipient: secondary_manager,
      kind: "manager.created",
      extra_info: {
        changed_fields: %w[first_name last_name email employee_id active],
        password_setup_email_enqueued: true
      }
    },
    {
      author: audit_author,
      recipient: secondary_manager,
      kind: "manager.updated",
      extra_info: {
        changed_fields: %w[email employee_id]
      }
    },
    {
      author: secondary_manager,
      recipient: secondary_manager,
      kind: "manager.self_email_changed",
      extra_info: {
        changed_fields: [ "email" ],
        old_email: "marc.soler.old@fitxa-cae.test",
        new_email: secondary_manager.email
      }
    },
    {
      author: secondary_manager,
      recipient: secondary_manager,
      kind: "manager.password_changed",
      extra_info: {
        changed_fields: [ "password" ],
        origin: "profile_page"
      }
    },
    {
      author: audit_author,
      recipient: audit_author,
      kind: "tag.created",
      extra_info: {
        tag_id: tags[:office].id,
        tag_name: tags[:office].name,
        tag_color: tags[:office].color,
        active: true
      }
    },
    {
      author: audit_author,
      recipient: audit_author,
      kind: "tag.updated",
      extra_info: {
        tag_id: tags[:wharehouse].id,
        tag_name: tags[:wharehouse].name,
        tag_color: tags[:wharehouse].color,
        changed_fields: %w[name color]
      }
    },
    {
      author: audit_author,
      recipient: audit_author,
      kind: "tag.deactivated",
      extra_info: {
        tag_id: tags[:off_shore].id,
        tag_name: tags[:off_shore].name,
        active: false
      }
    },
    {
      author: audit_author,
      recipient: audit_author,
      kind: "employee_bulk_action.enqueued",
      extra_info: {
        employee_bulk_action_run_id: 1,
        bulk_action_kind: "activation",
        action: "deactivate",
        affected_national_id_count: 8
      }
    },
    {
      author: audit_author,
      recipient: audit_author,
      kind: "report_export.downloaded",
      extra_info: {
        report_export_id: 1,
        report_kind: "company_zip",
        format: "zip",
        month: today.month,
        year: today.year,
        period: I18n.l(today.beginning_of_month, format: :month_year),
        filename: "fitxa-cae-empresa-demo.zip"
      }
    },
    {
      author: audit_author,
      recipient: audit_author,
      kind: "report.monthly_summary_csv_downloaded",
      extra_info: {
        report_kind: "monthly_summary",
        format: "csv",
        month: today.month,
        year: today.year,
        period: I18n.l(today.beginning_of_month, format: :month_year)
      }
    },
    {
      author: audit_author,
      recipient: audit_author,
      kind: "audit_actions.exported",
      extra_info: {
        exported_count: 100,
        limit: 100,
        filters: { author_type: "Manager" }
      }
    },
    {
      author: employee,
      recipient: employee,
      kind: "employee.profile_updated",
      extra_info: {
        changed_fields: %w[email phone]
      }
    },
    {
      author: employee,
      recipient: employee,
      kind: "employee.password_changed",
      extra_info: {
        changed_fields: [ "password" ],
        origin: "first_time"
      }
    },
    {
      author: employee,
      recipient: employee,
      kind: "human_resources_contact.submitted",
      extra_info: {
        subject: "Canvi de torn",
        delivery: "email",
        enqueued: true
      }
    }
  ]

  audit_rows << {
    author: pending_correction.requester,
    recipient: pending_correction.employee,
    kind: "swipe_correction.created",
    extra_info: seed_correction_audit_details(pending_correction)
  } if pending_correction

  audit_rows << {
    author: audit_author,
    recipient: approved_correction.employee,
    kind: "swipe_correction.approved",
    extra_info: seed_correction_audit_details(approved_correction)
  } if approved_correction

  audit_rows << {
    author: audit_author,
    recipient: rejected_correction.employee,
    kind: "swipe_correction.rejected",
    extra_info: seed_correction_audit_details(rejected_correction)
  } if rejected_correction

  audit_rows << {
    author: audit_author,
    recipient: approved_correction.employee,
    kind: "swipe_correction.approved_with_modifications",
    extra_info: seed_correction_audit_details(approved_correction, {
      origin: "admin_edit",
      original_correction_id: approved_correction.id,
      replacement_correction_id: approved_correction.id + 10_000
    })
  } if approved_correction

  audit_rows.each_with_index do |attributes, index|
    AuditAction.create!(
      attributes.merge(
        created_at: audit_started_at + (index * 4.hours),
        updated_at: audit_started_at + (index * 4.hours)
      )
    )
  end
end

puts "Seeded #{Employee.count} employees, #{Manager.count} managers, #{Tag.count} tags, " \
  "#{Swipe.count} swipes, #{SwipeCorrection.count} swipe corrections and #{AuditAction.count} audit actions."
