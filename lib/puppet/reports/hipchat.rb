require 'json'
require 'net/https'
require 'open-uri'
require 'puppet'
require 'uri'
require 'yaml'

# Support string formatter hashes in Ruby 1.8.7
# Courtesy of http://stackoverflow.com/questions/6258516/how-to-match-and-replace-templating-tags-in-ruby-rails

if RUBY_VERSION < '1.9.2'
  class String
    old_format = instance_method(:%)

    define_method(:%) do |arg|
      if arg.is_a?(Hash)
        self.gsub(/%\{(.*?)\}/) { arg[$1.to_sym] }
      else
        old_format.bind(self).call(arg)
      end
    end
  end
end

Puppet::Reports.register_report(:hipchat) do

  configfile = File.join([File.dirname(Puppet.settings[:config]), "hipchat.yaml"])
  raise(Puppet::ParseError, "Hipchat report config file #{configfile} not readable") unless File.exist?(configfile)

  config = YAML.load_file(configfile)

  HIPCHAT_API_TOKEN = config[:hipchat_api_token]
  HIPCHAT_ROOM = config[:hipchat_room]
  HIPCHAT_FROM = config[:hipchat_from] || 'Puppet'
  HIPCHAT_NOTIFY = config[:hipchat_notify] || '0'
  HIPCHAT_STATUSES = Array(config[:hipchat_statuses] || 'failed')
  DISABLED_FILE = File.join([File.dirname(Puppet.settings[:config]), 'hipchat_disabled'])
  FOREMAN_API_HOST = config[:foreman_api_host] || ''

  desc <<-DESC
  Send notification of failed reports to a Hipchat room.
  DESC

  def process
    # Disabled check here to ensure it is checked for every report
    disabled = File.exists?(DISABLED_FILE)

    if (get_statuses(HIPCHAT_STATUSES).include?(self.status) || get_statuses(HIPCHAT_STATUSES).include?('all')) && !disabled
      Puppet.debug "Sending status for #{self.host} to Hipchat channel #{HIPCHAT_ROOM}"

      msg = "Puppet run for #{self.host} #{self.status} at #{Time.now.asctime}"

      if FOREMAN_API_HOST != ''
        uri = URI.parse('http://%s/api/hosts/%s/reports/last' % [ FOREMAN_API_HOST, self.host ] )
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
        @data = response.body

        json = JSON.parse(@data)
        reportid = json['report']['id']
        msg = "Puppet run for <a href=\"http://foreman/hosts/reports/#{reportid}\">#{self.host}</a> #{self.status} at #{Time.now.asctime}"
      end

      color = case self.status
              when 'failed' then 'red'
              when 'changed' then 'purple'
              else 'green'
              end

      post_data = {
        'room_id' => HIPCHAT_ROOM,
        'from'    => HIPCHAT_FROM,
        #'color'   => get_color_by_status(HIPCHAT_STATUSES, self.status),
        'color'   => color,
        'notify'  => HIPCHAT_NOTIFY,
        'message' => msg
      }

      address = "http://api.hipchat.com/v1/rooms/message?format=json&auth_token=#{HIPCHAT_API_TOKEN}"

      begin
        Net::HTTP.post_form(URI(address), post_data)
      rescue => e
        puts e.class
        puts e.message
        puts e.backtrace
      end
    end
  end

=begin
  def get_color_by_status(hipchat_statuses, status)
    color = 'green'
    hipchat_statuses.each do |status_and_color|
      if status_and_color.key?(status)
        color = status_and_color[status]
        break
      end
    end
    return color
  end

  def get_statuses(hipchat_statuses)
    statuses = []
    hipchat_statuses.each do |status_and_color|
      status_and_color.each { |k, v|
        statuses << k
      }
    end
    return statuses
  end
=end
end
