module IRB
  module HelperMethod
    class Base
      class << self
        def category(category = nil)
          @category = category if category
          @category
        end

        def description(description = nil)
          @description = description if description
          @description
        end
      end
    end
  end
end
