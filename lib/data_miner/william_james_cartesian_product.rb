# http://www.ruby-forum.com/topic/95519#200484

module WilliamJamesCartesianProduct
  def self.cart_prod( *args )
    args.inject([[]]){|old,lst|
      new = []
      lst.each{|e| new += old.map{|c| c.dup << e }}
      new
    }
  end
end
