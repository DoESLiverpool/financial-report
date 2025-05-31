# app/services/categories_calculator.rb
class CategoriesCalculator
  FALLBACK_CATEGORY = "Other"
  FALLBACK_CATEGORY_DOWN = FALLBACK_CATEGORY.downcase

    def initialize
      # Build description lookup
      @description_map = {}
      ProductCategory.includes(:product_category_descriptions).find_each do |category|
        category.product_category_descriptions.each do |desc|
          @description_map[desc.description.downcase.strip] = category.name
        end
      end
  
      # Build regex fallback lookup
      @regex_map = {}
      ProductCategory.order(:id).find_each do |category|
        next unless category.regex.present?
        pattern = sanitize_regex(category.regex)
        @regex_map[pattern] = category.name
      end

      UnknownCategory.delete_all
    end
  
    def find_category(input, gross_value)
      input_down = input.downcase.strip

      if input_down == FALLBACK_CATEGORY_DOWN
        return FALLBACK_CATEGORY
      end

      # Exact description match
      if @description_map[input_down]
        return @description_map[input_down]
      end
  
      # Regex fallback
      @regex_map.each do |pattern, name|
        return name if input.match?(pattern)
      end
      puts "Unknown category: ###{input}### #{gross_value}"
      UnknownCategory.create(description: input, price: gross_value)
      
      FALLBACK_CATEGORY
    end
  
    private
  
    def sanitize_regex(regex)
        stripped = regex.gsub(/\A\^?/, "").gsub(/\$?\z/, "")
        Regexp.new("^#{stripped}$", Regexp::IGNORECASE)
    end
end
  