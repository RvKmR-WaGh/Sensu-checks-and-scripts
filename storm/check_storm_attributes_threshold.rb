#!/usr/bin/env ruby
# Storm Check attributes of spouts and bolts
# Author : Ravikumar Wagh

require 'sensu-plugin/check/cli'
require 'rest-client'
require 'openssl'
require 'uri'
require 'json'

class CheckStormThreshold < Sensu::Plugin::Check::CLI
    option :host,
        short: '-h',
        long: '--host=VALUE',
        description: 'Cluster host',
        required: true

    option :port,
        short: '-p',
        long: '--port=VALUE',
        description: 'port',
        required: true

    option :ssl,
        description: 'use HTTPS (default false)',
        long: '--ssl'

    option :crit,
        short: '-c',
        long: '--critical=VALUE',
        description: 'Critical threshold',
        required: true,
        proc: proc { |l| l.to_f }

    option :timeout,
        short: '-o',
        long: '--timeout=VALUE',
        description: 'Timeout in seconds',
        proc: proc { |l| l.to_f },
        default: 600

    option :timestamp,
        short: '-t',
        long: '--timestamp=VALUE',
        description: 'Timestamp in seconds',
        proc: proc { |l| l.to_str },
        default: ':all-time'

    option :spout_attribute,
        short: '-s',
        long: '--spout=VALUE',
        description: 'check threashold of spouts',
        default: 'failed'


    option :bolt_attribute,
        short: '-b',
        long: '--bolt=VALUE',
        description: 'check threashold of bolts',
        default: 'failed'

    def request(path)
        protocol = config[:ssl] ? 'https' : 'http'
        RestClient::Request.execute(
            method: :get,url: "#{protocol}://#{config[:host]}:#{config[:port]}/#{path}",
            timeout: config[:timeout]
        )
    end

    def check_attributes(topology)
        req = request("api/v1/topology/#{topology['id']}?window=#{config[:timestamp]}")
        if req.code != 200
            critical "unexpected status code '#{req.code}'"
        end
        bolts = JSON.parse(req.to_str)['bolts']
        spouts = JSON.parse(req.to_str)['spouts']
        bolt_value = check_bolt_attributes(topology, bolts, config[:bolt_attribute])
        spout_value = check_spouts_attributes(topology, spouts, config[:spout_attribute])
    return bolt_value, spout_value
    end

    def check_bolt_attributes(topology, bolts, attribute)
        bolt_value = 0.0
        bolts.each do |bolt|
            critical "Bolt Attribute : '#{attribute}' is unknown to storm. " if bolt[attribute].nil?
            bolt_value = bolt[attribute].to_f
            if bolt_value > config[:crit]
                critical "Bolt Attribute : '#{attribute}' is exceeding critical limit : #{bolt_value} for bolt '#{bolt['boltId']}' in topology '#{topology['name']}'"
            end
        end
        return bolt_value
    end

    def check_spouts_attributes(topology, spouts, attribute)
        spout_value = 0.0
        spouts.each do |spout|
            critical "Spout Attribute : '#{attribute}' is unknown to storm. " if spout[attribute].nil?
            spout_value = spout[attribute].to_f
            if spout_value > config[:crit]
                critical "Spout Attribute : '#{attribute}' is exceeding critical limit : #{spout_value} for spout '#{spout['spoutId']}' in topology '#{topology['name']}'"
            end
        end
        return spout_value
    end

    def run
        value = [0.0, 0.0]
        req = request('api/v1/topology/summary')
        if req.code != 200
            critical "Storm topology check has unexpected status code:  '#{req.code}'"
        end
        topologies = JSON.parse(req.to_str)['topologies']
        topologies.each do |topology|
          value = check_attributes(topology)
        end
        ok "Bolts : '#{value[0]}' and spouts: '#{value[1]}' are within threashold limit"
        rescue Errno::ECONNREFUSED => e
            critical 'Storm is not responding' + e.message
        rescue RestClient::RequestTimeout
            critical 'Storm Connection timed out'
        rescue StandardError => e
            unknown 'An exception occurred:' + e.message
    end
end
