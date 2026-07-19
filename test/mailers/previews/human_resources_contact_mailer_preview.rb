# Preview all emails at http://localhost:3000/rails/mailers/human_resources_contact_mailer
class HumanResourcesContactMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/human_resources_contact_mailer/contact_request
  def contact_request
    employee = Employee.first || Employee.new(
      first_name: "Ada",
      last_name: "Soler",
      national_id: "12345678Z",
      email: "ada@example.test",
      phone: "+34 600 111 222"
    )

    HumanResourcesContactMailer.contact_request(
      employee,
      subject: "Consulta de vacances",
      body: "Bon dia,\n\nTinc una consulta per a Recursos Humans."
    )
  end
end
