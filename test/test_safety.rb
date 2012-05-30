# -*- encoding: utf-8 -*-
require 'helper'
init_database
init_pet
require 'earth'

require 'lock_method'
DataMiner::Run.lock_method :start

# use earth, which has a plethora of real-world data_miner blocks
Earth.init :locality, :pet, :load_data_miner => true, :apply_schemas => true

describe DataMiner do
  describe "when being run in a multi-threaded environment" do
    before do
      @old_thread_abort_on_exception = Thread.abort_on_exception
      Thread.abort_on_exception = false
    end

    after do
      Thread.abort_on_exception = @old_thread_abort_on_exception
    end

    it "tries not to duplicate data" do
      Breed.delete_all
      Breed.run_data_miner!
      reference_count = Breed.count
      Breed.delete_all
      threads = (0..2).map do |i|
        Thread.new do
          # $stderr.write "Thread #{i} starting\n"
          Breed.run_data_miner!
          # $stderr.write "Thread #{i} done\n"
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
    end

    it "allows you to clear locks if necessary" do
      threads = (0..2).map do |i|
        Thread.new do
          # $stderr.write "Thread #{i} starting\n"
          case i
          when 0
            Breed.run_data_miner! 
          when 1
            sleep 0.3
            DataMiner::Run.clear_locks
            Breed.run_data_miner!
          when 2
            # i will hit a lock!
            sleep 0.6
            Breed.run_data_miner!
          end
          # $stderr.write "Thread #{i} done\n"
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
      exceptions.length.must_equal 1
      exceptions.each do |exception|
        exception.must_be_kind_of LockMethod::Locked
      end
    end
  end
end
