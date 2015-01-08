module Fluent
  class DosBlockAclOutput < TimeSlicedOutput
    Fluent::Plugin.register_output('dos_block_acl', self)

    config_param :network_acl_id, :string
    config_param :dryrun, :bool, :default => false
    config_param :ip_address_key, :string
    config_param :dos_threshold, :integer
    config_param :aws_key_id, :string, :default => nil
    config_param :aws_sec_key, :string, :default => nil
    config_param :region, :string, :default => nil
    config_param :white_list, :string, :default => '127.0.0.1'
    config_param :deny_rule_numbers_range, :string, :default => '1..18'
    config_param :state_file, :string, :default => nil

    def initialize
      super
      require 'aws-sdk'
      require 'pathname'
    end

    def configure(conf)
      super
      @white_list = @white_list.split(',')
      unless eval(@deny_rule_numbers_range).class == Range
        raise Fluent::ConfigError, "out_dos_block_acl: @deny_rule_numbers_range is not Range!"
      end
      @deny_rule_numbers_range = eval(@deny_rule_numbers_range).to_a
      @acl_entry_limit = @deny_rule_numbers_range.size
    end

    def start
      super
      AWS.config(access_key_id: @aws_key_id, secret_access_key: @aws_sec_key, region: @region)
      @ec2 = AWS::EC2::Client.new
      acls = @ec2.describe_network_acls(network_acl_ids: [@network_acl_id])
      @allow_any_rule_number = acls[:network_acl_set].first[:entry_set].select {|r|
                         !r[:egress] && r[:cidr_block] == "0.0.0.0/0" && r[:rule_action] == "allow"
                       }.first[:rule_number]

      state = @state_file ? load_status(@state_file) : nil

      if state.nil?
        @rule_numbers = get_deny_rule_numbers
        @next_rule_index = get_next_rule_index
      else
        @rule_numbers = state[:rule_numbers]
        @next_rule_index = state[:next_rule_index]
      end
      $log.info("out_dos_block_acl: use deny rule numbers => #{@rule_numbers}")
    end

    def shutdown
      super
      unless @state_file.nil?
        save_status(@state_file)
      end
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      begin
        ip_addresses = []
        chunk.msgpack_each do |(tag,time,record)|
          ip_addresses << record[@ip_address_key]
        end
        counts = group_count(ip_addresses)
        dos_hash = counts.select {|k, v| v >= @dos_threshold }
        regist_deny_acl(dos_hash.keys)
      rescue => e
        $log.error("\n#{e.message}\n#{e.backtrace.join("\n")}")
      end
    end

    private

    def group_count(list)
      Hash[list.group_by{ |e| e }.map{ |k, v| [k, v.length] }]
    end

    def regist_deny_acl(ip_addresses)
      unless ip_addresses.empty?
        ip_addresses.each do |ip_address|
          next if @white_list.include?(ip_address)
          deny_rules = get_deny_rules
          unless deny_rules.any? {|r| r[:cidr_block] == "#{ip_address}/32"}
            @next_rule_index = 0 if @rule_numbers.size == @next_rule_index
            rule_number = @rule_numbers[@next_rule_index]
            if deny_rules.any? {|r| r[:rule_number] == rule_number}
              delete_deny_acl(rule_number)
            end
            option = {
              network_acl_id: @network_acl_id,
              rule_number: rule_number,
              rule_action: 'deny',
              protocol: '-1',
              cidr_block: "#{ip_address}/32",
              egress: false
            }
            @ec2.create_network_acl_entry(option) unless @dryrun
            $log.info("netowork acl regist! deny ip_address => #{ip_address}, rule_number => #{rule_number}")
            @next_rule_index = @next_rule_index + 1
          end
        end
      end
    end

    def delete_deny_acl(rule_number)
      option = {
        network_acl_id: @network_acl_id,
        rule_number: rule_number,
        egress: false
      }
      $log.info("delete, rule_number => #{rule_number}")
      @ec2.delete_network_acl_entry(option) unless @dryrun
    end

    def get_deny_rules
      get_all_rules.select {|r|
        !r[:egress] &&
        r[:rule_number] < @allow_any_rule_number &&
        @deny_rule_numbers_range.include?(r[:rule_number])
      }.sort_by {|r| r[:rule_number]}
    end

    def get_deny_rule_numbers
      get_deny_rules.map { |r| r[:rule_number]}.concat(@deny_rule_numbers_range).uniq.first(@acl_entry_limit)
    end

    def get_all_rules
      acls = @ec2.describe_network_acls(network_acl_ids: [@network_acl_id])
      acls[:network_acl_set].first[:entry_set]
    end

    def get_next_rule_index
      deny_rules = get_deny_rules
      next_rule_index = 0
      if get_all_rules.size >= @acl_entry_limit
        next_rule_index = 0
      else
        next_rule_index = deny_rules.empty? ? 0 : deny_rules.size
      end
      next_rule_index
    end

    def save_status(file_path)
      begin
        Pathname.new(file_path).open('wb') do |f|
          Marshal.dump({
            rule_numbers: @rule_numbers,
            next_rule_index: @next_rule_index
          }, f)
        end
      rescue => e
        $log.warn "out_dos_block_acl: Can't write store_file #{e.class} #{e.message}"
      end
    end

    def load_status(file_path)
      return nil unless File.exist?(file_path)
      state = Marshal.load(File.read(file_path))
      state[:rule_numbers] = state[:rule_numbers].concat((1..@acl_entry_limit).to_a).uniq.first(@acl_entry_limit)
      state[:next_rule_index] = state[:next_rule_index] > @acl_entry_limit ? 0 : state[:next_rule_index]
      state
    end
  end
end

