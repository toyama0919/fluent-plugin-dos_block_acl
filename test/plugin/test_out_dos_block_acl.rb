require 'helper'
class DosBlockAclOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  DEFAULT_CONFIG = %[
  ]

  def stub_seed_values
    time = Time.parse("2014-01-01 00:00:00 UTC").to_i
    records = [{"a" => 1}, {"a" => 2}]
    return time, records
  end

  def create_driver(conf = DEFAULT_CONFIG)
    config = %[
      network_acl_id acl-xxxxxx
      ip_address_key ip_address
      dos_threshold 1000
      time_slice_wait 10s
      buffer_path tmp/buffer
    ] + conf

    Fluent::Test::TimeSlicedOutputTestDriver.new(Fluent::DosBlockAclOutput) do
      def write(chunk)
        chunk.instance_variable_set(:@key, @key)
        super(chunk)
      end
    end.configure(config)
  end

  def test_configure
    d = create_driver

    {
      :@dos_threshold => 1000,
      :@deny_rule_numbers_range => (1..18).to_a,
      :@ip_address_key => 'ip_address'
    }.each { |k, v|
      assert_equal(d.instance.instance_variable_get(k), v)
    }
  end

  def test_configure_error
    assert_raise(Fluent::ConfigError) do
      create_driver(%[deny_rule_numbers_range 1])
    end

    assert_raise(Fluent::ConfigError) do
      create_driver(%[deny_rule_numbers_range 1.10])
    end
  end

  def test_emit
    d = create_driver
    time, records = stub_seed_values
  end
end
