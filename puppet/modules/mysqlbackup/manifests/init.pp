class mysqlbackup {
  include s3backup
  include mysql::server
  File { ensure => present, owner => 's3backup', group => 's3backup', mode => 700 }

  file {'/home/s3backup/s3backup-db.sh' :
    content => template('mysqlbackup/s3backup-db.sh.erb'),
  }

  package {'libmysqlclient-dev' : ensure => present }
  package {'mysql' : ensure => present, provider => 'gem', require => Package['libmysqlclient-dev'] }
  # todo install mysql gem

  Mysql_database { defaults => '/etc/mysql/debian.cnf' }

  define database () {
    mysql_database { $name : ensure => present }

    cron { "sync_${name}" :
      ensure   => present,
      command  => "/home/s3backup/s3backup-db.sh ${name}",
      environment => ['S3CONF=/home/s3backup/.s3conf/'],
      user     => 's3backup',
      minute   => '*',
      hour     => '*',
      monthday => '*',
      month    => '*',
      weekday  => '*',
      require  => Mysql_database[$name],
    }
  }
}

class s3backup {
  package { 'aws-s3' : ensure => installed, provider => 'gem' }
  File { ensure => present, owner => 's3backup', group => 's3backup', mode => 700 }

  file { '/home/s3backup' : ensure => directory, }
  file { ['/home/s3backup/mysql_backups/', '/home/s3backup/.s3conf/'] : ensure => directory, require => File['/home/s3backup'] }

  file {'/home/s3backup/.s3conf/s3config.yml' :
    require => File['/home/s3backup/.s3conf/'],
    content => template('mysqlbackup/s3config.yml.erb'),
  }

  file {'/home/s3backup/s3restore-db.rb' :
    require => File['/home/s3backup/.s3conf/'],
    content => template('mysqlbackup/s3restore-db.rb.erb'),
  }

  # this includes s3sync.rb
  file {'/home/s3backup/s3sync' :
    source  => 'puppet:///modules/mysqlbackup/s3sync',
    recurse => true,
  }

  user {'s3backup' :
    ensure     => present,
    managehome => true,
    home       => '/home/s3backup',
  }
}
