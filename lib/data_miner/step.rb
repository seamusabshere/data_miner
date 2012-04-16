class DataMiner::Step
  def ==(other)
    other.class == self.class and other.description == description
  end
end
