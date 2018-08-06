class AccountingPeriod < ApplicationRecord
  def description
    "#{start_date.year}-#{end_date.year}"
  end

  def self.which(date)
    all.each do |ap|
      if ap.start_date <= date and ap.end_date >= date
        return ap
      end
    end
    return nil
  end
end
