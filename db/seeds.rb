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

ActiveRecord::Base.transaction do
  AuditAction.delete_all
  SwipeCorrection.delete_all
  Swipe.delete_all
  Manager.delete_all
  ActiveRecord::Base.connection.execute("DELETE FROM employees_tags")
  Employee.delete_all
  Tag.delete_all

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
      requested_swipes = [
        {
          "kind" => "entry",
          "swipe_at" => work_time(day, 8, rng.rand(0..20)).iso8601
        },
        {
          "kind" => "exit",
          "swipe_at" => work_time(day, 17, rng.rand(0..30)).iso8601
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
          "requested_swipes" => requested_swipes,
          "reason" => CORRECTION_REASONS.sample(random: rng)
        },
        requester_comments: CORRECTION_REASONS.sample(random: rng),
        validator_comments: validator ? "#{status}: revisat pel responsable de torn" : nil
      )
    end
  end
end

puts "Seeded #{Employee.count} employees, #{Manager.count} managers, #{Tag.count} tags, " \
  "#{Swipe.count} swipes and #{SwipeCorrection.count} swipe corrections."
