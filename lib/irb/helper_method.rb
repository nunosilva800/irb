require_relative "helper_method/base"

module IRB
  module HelperMethod
    @helper_methods = {}

    class << self
      attr_reader :helper_methods

      def register(name, helper_class)
        @helper_methods[name] = helper_class
      end

      def all_helper_methods_info
        @helper_methods.map do |name, helper_class|
          { display_name: name, description: helper_class.description, category: helper_class.category }
        end
      end
    end

    # Default helper_methods
    require_relative "helper_method/measure"
    register(:measure, HelperMethod::Measure)
  end
end
