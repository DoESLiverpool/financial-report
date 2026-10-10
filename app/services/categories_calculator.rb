# app/services/categories_calculator.rb
class CategoriesCalculator
  FALLBACK_CATEGORY = "Other"
  FALLBACK_CATEGORY_DOWN = FALLBACK_CATEGORY.downcase

    def initialize
      # Build description lookup
      @description_map = {}
      ProductCategory.includes(:product_category_descriptions).find_each do |category|
        category.product_category_descriptions.each do |desc|
          @description_map[normalize(desc.description)] = category.name
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
      input_down = normalize(input)

      if input_down == FALLBACK_CATEGORY_DOWN
        return FALLBACK_CATEGORY
      end

      # Exact description match
      if @description_map[input_down]
        return @description_map[input_down]
      end
  
      # Regex fallback
      @regex_map.each do |pattern, name|
        return name if input_down.match?(pattern)
      end
      UnknownCategory.create(description: input, price: gross_value)
      
      FALLBACK_CATEGORY
    end
  
    private

    # Bank descriptions arrive padded with runs of spaces, tabs and newlines,
    # and the padding changes over time, so both the listed descriptions and
    # the text being matched are squeezed down to single spaces first.  Note
    # that UnknownCategory still records the original spelling, since that is
    # what you need to see when adding to categories.csv.
    def normalize(text)
      text.to_s.downcase.gsub(/\s+/, " ").strip
    end

    def sanitize_regex(regex)
        stripped = regex.gsub(/\A\^?/, "").gsub(/\$?\z/, "")
        Regexp.new("^#{stripped}$", Regexp::IGNORECASE)
    end
end
  