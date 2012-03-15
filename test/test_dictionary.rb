# encoding: UTF-8

$:.push File.dirname(__FILE__)
require 'helper'

class TestDataMinerDictionary < Test::Unit::TestCase
  context '#lookup' do
    setup do
      @test_countries = [
        {:name => 'Germany',       :upcase => 'GERMANY',       :downcase => 'germany',       :code => 'DE'},
        {:name => 'Åland Islands', :upcase => 'ÅLAND ISLANDS', :downcase => 'åland islands', :code => 'AX'},
        {:name => "Côte d'Ivoire", :upcase => "CÔTE D'IVOIRE", :downcase => "côte d'ivoire", :code => 'CI'}
      ]
    end
    
    context 'case sensitive' do
      setup do
        options = {
          :input => 'name',
          :output => 'iso_3166_code',
          :url => "file://#{File.expand_path ::File.dirname(__FILE__)}/support/countries.csv"
        }
        @dict = DataMiner::Dictionary.new DataMiner.recursively_stringify_keys(options)
      end
      
      should "find exact matches" do
        @test_countries.each do |country|
          assert_equal @dict.lookup(country[:name]), country[:code]
        end
      end
      
      should "not find matches with case differences" do
        @test_countries.each do |country|
          assert_nil @dict.lookup(country[:upcase])
          assert_nil @dict.lookup(country[:downcase])
        end
      end
    end
    
    context 'case insensitive lookup' do
      setup do
        options = {
          :input => 'name',
          :output => 'iso_3166_code',
          :url => "file://#{File.expand_path ::File.dirname(__FILE__)}/support/countries.csv",
          :case_sensitive => false
        }
        @dict = DataMiner::Dictionary.new DataMiner.recursively_stringify_keys(options)
      end
      
      should "find exact matches" do
        @test_countries.each do |country|
          assert_equal @dict.lookup(country[:name]), country[:code]
        end
      end
      
      should "find matches with case differences" do
        @test_countries.each do |country|
          assert_equal @dict.lookup(country[:upcase]), country[:code]
          assert_equal @dict.lookup(country[:downcase]), country[:code]
        end
      end
    end
  end
end
