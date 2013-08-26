class hipchat (
  $api_token,
  $room,
  $from = 'Puppet',
  $notify = '1',
  $statuses     = [ 'failed', 'changed' ],
  $config_file  = '/etc/puppet/hipchat.yaml',
){

  file { $config_file:
    ensure  => file,
    owner   => 'puppet',
    group   => 'puppet',
    mode    => '0440',
    content => template('puppet_hipchat/hipchat.yaml.erb'),
  }

}

