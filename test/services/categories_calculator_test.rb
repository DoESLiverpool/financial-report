require 'test_helper'

class CategoriesCalculatorTest < ActiveSupport::TestCase
  setup do
    @calculator = CategoriesCalculator.new
  end

  test "matches a description exactly" do
    assert_equal "Monthly Desk", @calculator.find_category("Permanent Desk", 1)
  end

  test "matches a description ignoring case and surrounding whitespace" do
    assert_equal "Monthly Desk", @calculator.find_category("  permanent desk ", 1)
  end

  # The bank pads names out with runs of spaces ("Joe   Bloggs A"), and it
  # changes how many it uses over time, so a listed description would otherwise
  # silently stop matching.
  test "matches a description despite a run of internal whitespace" do
    assert_equal "Monthly Desk", @calculator.find_category("Permanent   Desk", 1)
  end

  test "matches a description that spans several lines" do
    assert_equal "Event Hire", @calculator.find_category("Room hire\nand use\tof services", 1)
  end

  test "matches a regex despite a run of internal whitespace" do
    assert_equal "Monthly Desk", @calculator.find_category("Paid for a Permanent   Desk in March", 1)
  end

  test "falls back to Other and records what it could not place" do
    assert_equal "Other", @calculator.find_category("Totally Unknown   Payment", 12.5)
    unknown = UnknownCategory.last
    assert_equal "Totally Unknown   Payment", unknown.description,
      "the original spelling is what you need to see when improving categories.csv"
    assert_equal 12.5, unknown.price
  end

  test "treats a literal 'Other' as the fallback" do
    assert_equal "Other", @calculator.find_category("Other", 1)
  end
end
