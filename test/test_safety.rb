# -*- encoding: utf-8 -*-
require 'helper'
require 'earth'

# use earth, which has a plethora of real-world data_miner blocks
Earth.init :locality, :pet, :load_data_miner => true, :apply_schemas => true

describe DataMiner do
  describe "when being run in a multi-threaded environment" do
    it "tries not to duplicate data" do
      begin
        old_thread_abort_on_exception = Thread.abort_on_exception
        Thread.abort_on_exception = false
        Breed.delete_all
        Breed.run_data_miner!
        reference_count = Breed.count
        Breed.delete_all
        threads = (0..2).map do |i|
          Thread.new do
            $stderr.write "Thread #{i} starting\n"
            Breed.run_data_miner!
            $stderr.write "Thread #{i} done\n"
          end
        end
        exceptions = []
        threads.each do |t|
          begin
            t.join
          rescue
            exceptions << $!
          end
        end
        exceptions.length.must_equal 2
        exceptions.each do |exception|
          exception.must_be_kind_of LockMethod::Locked
        end
        Breed.count.must_equal reference_count
      ensure
        Thread.abort_on_exception = old_thread_abort_on_exception
      end
    end
  end
end
