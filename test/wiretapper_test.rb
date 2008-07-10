require 'test/unit'
require "ruby2ruby"
require "mechanize"
require "mocha"
require "../lib/fake_mechanics"

class FakeMechanicsTest < Test::Unit::TestCase
  # Replace this with your real tests.
  def setup
    @datastore = SQLiteDatastore.new('test')
    @wiretapper = NetHTTPWiretapper.new(:data_store => @datastore)
    @agent = WWW::Mechanize.new
  end
  
  
  def test_wiretap_removed_if_exception_raised
    m_proc = lambda { Net::HTTP.instance_method(:request).to_ruby }
    m = m_proc.call
    assert_raise(Exception) do
      @wiretapper.snoop { raise Exception }
    end
    assert_equal m, m_proc.call
  end
  
  # def test_wiretap_method_replaces_original
  #   m_proc = lambda { Net::HTTP.instance_method(:request).to_ruby }
  #   m = m_proc.call
  #   wiretap_method = nil
  #   @wiretapper.snoop do
  #     wiretap_method = Net::HTTP.instance_method(:request).to_ruby
  #   end
  #   assert wiretap_method != m
  # end
  
  def test_wiretap_returns_captured_data
    @wiretapper.expects(:captured_transmission).returns(23)
    ret = nil
    @wiretapper.snoop do
      ret = Net::HTTP.new("http://www.google.com").request(nil)
    end
    assert_equal 23, ret
  end
  
  def test_wiretap_checks_data_store_for_captured_data
    @datastore.expects(:get).returns(Marshal.dump([1,23]))
    ret = nil
    @wiretapper.snoop do
      ret = Net::HTTP.new("http://www.google.com").request(nil)
    end
    assert_equal [1,23], ret
  end
  
  
  def test_wiretap_captures_data
    @wiretapper.stubs(:create_key).returns(1)
    Net::HTTP.any_instance.expects(:request).returns(23).at_least_once
    @datastore.expects(:get).returns(false).at_least_once
    @datastore.expects(:store).returns(true).with(1,Marshal.dump(23))
    @wiretapper.snoop do
      ret = Net::HTTP.new("www.google.com").request_get("/")
    end
  end
  
  def test_create_key
    assert @wiretapper.create_key(23)
  end
end
