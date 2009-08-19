module DataMiner
  module Reportable
    class Report
      attr_accessor :instance, :affected, :components

      def initialize(instance, affected, components, subreports)
        @instance = instance
        @affected = affected
        @components = components
        incorporate(subreports)
      end
      
      def summary
        components[:summary].join(' ')
      end
      
      def to_s
        <<-EOS
Report on '#{affected}'
#{components_with_values.map { |k, v| "#{k}:\n  #{v.join("\n  ").strip}\n"}}
        EOS
      end

      private
      
      def components_with_values
        components.sort_by { |k, _| k.to_s }.reject { |_, v| v.blank? }
      end

      def incorporate(subreports)
        subreports.flatten.compact.each do |subreport|
          COMPONENTS.each do |component|
            self.components[component] = Array.wrap(self.components[component])
            self.components[component] << subreport.components[component] unless subreport.components[component].blank?
          end
        end
      end
    end
  end
end
