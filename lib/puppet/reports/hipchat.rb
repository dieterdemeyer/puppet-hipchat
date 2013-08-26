require 'json'
require 'net/https'
require 'open-uri'
require 'puppet'
require 'uri'
require 'yaml'

begin
  require 'hipchat'
rescue LoadError => e
  Puppet.info "You need the `hipchat` gem to use the Hipchat report"
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

    if (HIPCHAT_STATUSES.include?(self.status) || HIPCHAT_STATUSES.include?('all')) && !disabled
      Puppet.info "Sending status for #{self.host} to Hipchat channel #{HIPCHAT_ROOM}"

      msg = "Puppet run executed on #{self.host} with status #{self.status} at #{Time.now.asctime}"

      if FOREMAN_API_HOST != ''
        uri = URI.parse('%s/api/hosts/%s/reports/last' % [ FOREMAN_API_HOST, self.host ] )
        http = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == 'https' then
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
        @data = response.body

        json = JSON.parse(@data)
        reportid = json['report']['id']
        msg = "Puppet run executed on <a href=\"#{FOREMAN_API_HOST}/hosts/#{self.host}\">#{self.host}</a> "
        msg += "with status <a href=\"#{FOREMAN_API_HOST}/reports/#{reportid}\">#{self.status}</a> at #{Time.now.asctime}"
      end

      color = case self.status
              when 'failed' then 'red'
              when 'changed' then 'purple'
              else 'green'
              end

      client = HipChat::Client.new(HIPCHAT_API_TOKEN)
      client[HIPCHAT_ROOM].send(HIPCHAT_FROM, msg, :notify => HIPCHAT_NOTIFY, :color => color)
    end
  end

end
