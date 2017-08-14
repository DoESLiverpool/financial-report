Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  get "/reports/categories", to: "reports#categories"
  get "/reports/income_distribution", to: "reports#income_distribution"
  get "/reports/service_users", to: "reports#service_users"
end
