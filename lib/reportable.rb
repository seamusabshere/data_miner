module DataMiner
  module Reportable
    COMPONENTS = [ :summary, :urls, :klass ]
    
    def report_on(options = {})
      affected = options.delete(:affected)
      return unless reportably_affects?(affected)
      Report.new(self, affected, report_components, subreports(affected))
    end
    
    protected
    
    def report_components
      COMPONENTS.find_all { |component| respond_to?(report_component_method(component)) }.inject({}) do |memo, component|
        memo.merge(component => send(report_component_method(component)))
      end
    end
    
    def report_component_method(component)
      "report_#{component}"
    end
    
    def subreports(affected)
      all_reporters.map { |subreporter| subreporter.report_on(:affected => affected) if subreporter.respond_to?(:report_on) }
    end
    
    def all_reporters
      all = []
      all += Array.wrap(reporters) if respond_to?(:reporters)
      all += Array.wrap(reporter) if respond_to?(:reporter)
      all
    end
  end
end
