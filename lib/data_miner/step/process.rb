class DataMiner::Step::Process
  attr_reader :config
  attr_reader :method_id
  attr_reader :description
  attr_reader :blk

  alias :block_description :description

  def initialize(config, method_id_or_description, ignored_options = {}, &blk)
    @config = config
    if block_given?
      @description = method_id_or_description
      @blk = blk
    else
      @description = method_id_or_description
      @method_id = method_id_or_description
    end
  end
  
  def model
    config.model
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
