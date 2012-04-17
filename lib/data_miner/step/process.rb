class DataMiner::Step::Process
  attr_reader :script
  attr_reader :method_id
  attr_reader :description
  attr_reader :blk

  alias :block_description :description

  def initialize(script, method_id_or_description, ignored_options = {}, &blk)
    @script = script
    if block_given?
      @description = method_id_or_description
      @blk = blk
    else
      @description = method_id_or_description
      @method_id = method_id_or_description
    end
  end
  
  def model
    script.model
  end
  
  def perform
    if blk
      model.instance_eval(&blk)
    else
      model.send method_id
    end
    nil
  end
end
