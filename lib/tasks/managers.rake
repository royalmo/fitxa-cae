namespace :managers do
  desc "Create the first manager and send a password setup email"
  task create_first: :environment do
    email = Manager.normalize_email(ENV["EMAIL"])
    abort "Usage: bin/rails managers:create_first EMAIL=admin@example.com FIRST_NAME=Nom LAST_NAME=Cognoms" if email.blank?

    manager = Manager.find_by(email: email)
    existing_manager_count = Manager.where.not(email: email).count

    if existing_manager_count.positive? || manager&.password_digest.present?
      abort "A manager already exists. Use the admin UI or password reset flow instead."
    end

    manager ||= Manager.new(email: email)
    manager.assign_attributes(
      first_name: ENV["FIRST_NAME"].presence || manager.first_name,
      last_name: ENV["LAST_NAME"].presence || manager.last_name,
      active: true
    )
    manager.save!

    ManagerPasswordMailer.password_setup(manager).deliver_now
    puts "Manager #{manager.email} is ready. Password setup email sent."
  end
end
