class CreateAccountingPeriods < ActiveRecord::Migration[5.2]
  def change
    create_table :accounting_periods do |t|
      t.date :start_date, required: true
      t.date :end_date, required: true

      t.timestamps
    end
  end
end
