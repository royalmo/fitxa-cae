module Employee::ClockingsHelper
  def clocking_month_total_label(month)
    l(month, format: :month_year).sub(/\A./) { |character| character.upcase }
  end
end
